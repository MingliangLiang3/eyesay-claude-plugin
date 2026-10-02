# EyeSay: send a folder's photos to a photo job; prints the job's result last (Windows).
# usage: & ([scriptblock]::Create((Get-Content -Raw <path>\intake.ps1))) <job URL> <token> <folder> [--xmp | --xmp-suggestions]
# --xmp: afterwards write each photo's tags as an XMP sidecar (<name>.xmp) next to the original, for
#        Lightroom, Bridge and Photo Mechanic; never over an existing .xmp, photos never touched.
#        --xmp-suggestions adds the tags EyeSay is less sure of.
param([Parameter(Mandatory = $true)][string]$Url,
      [Parameter(Mandatory = $true)][string]$Token,
      [Parameter(Mandatory = $true)][string]$Dir,
      [switch]$Xmp,
      [switch]$XmpSuggestions,
      [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)

$ErrorActionPreference = 'Stop'
if ($Rest -contains '--xmp') { $Xmp = $true }
if ($Rest -contains '--xmp-suggestions') { $XmpSuggestions = $true }
$wantXmp = $Xmp -or $XmpSuggestions
if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { Write-Error "eyesay: no such folder: $Dir"; exit 2 }
$root = (Resolve-Path -LiteralPath $Dir).Path.TrimEnd('\', '/')
$exts = @('.jpg', '.jpeg', '.png', '.heic', '.heif', '.webp')
$files = Get-ChildItem -LiteralPath $root -Recurse -File |
    Where-Object { $exts -contains $_.Extension.ToLower() -and $_.FullName.Substring($root.Length) -notmatch '[\\/]\.' -and
                   $_.FullName.Substring($root.Length) -notmatch '^[\\/]EyeSay[\\/]' }
$count = @{ ok = 0; duplicate = 0; failed = 0; busy = 0 }
$stop = $null
foreach ($f in $files) {
    if ($stop) { break }
    $name = [Uri]::EscapeDataString($f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/'))
    $headers = @{ 'X-Intake-Token' = $Token; 'X-File-Name' = $name }
    for ($try = 0; $try -lt 10; $try++) {
        try {
            $r = Invoke-RestMethod -Method Post -Uri $Url -InFile $f.FullName `
                -ContentType 'application/octet-stream' -Headers $headers
            if ($r.status -eq 'duplicate') { $count.duplicate++ } else { $count.ok++ }
            break
        } catch {
            $code = 0
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
            $text = "$($_.ErrorDetails.Message)"
            if ($code -eq 401) { $stop = 'the upload token lapsed, ask for a new one with prepare_upload and run again'; break }
            if ($code -eq 429 -and $text -match '"stopped"') { $stop = "the account's photos are used up"; break }
            if (($code -eq 429 -or $code -eq 503) -and $try -lt 9) { Start-Sleep -Seconds 2; continue }
            if ($code -eq 429 -or $code -eq 503) { $count.busy++ } else { $count.failed++ }
            break
        }
    }
}
$line = "eyesay: $($count.ok) sent and tagged, $($count.duplicate) already in the job, $($count.failed) failed"
if ($count.busy) { $line += ", $($count.busy) busy (run again)" }
if ($stop) { $line += "; STOPPED: $stop" }
Write-Output $line
if ($stop) { exit 1 }
if (-not $wantXmp) {
    Write-Output (Invoke-RestMethod -Uri "$Url/summary" -Headers @{ 'X-Intake-Token' = $Token })
} else {
    $want = if ($XmpSuggestions) { 'all' } else { '1' }
    $summary = Invoke-RestMethod -Uri "$Url/summary?xmp=$want" -Headers @{ 'X-Intake-Token' = $Token }
    Write-Output $summary
    $link = $null
    foreach ($l in ("$summary" -split "`r?`n")) { if ($l -match '^XMP sidecars.*\): (\S+)$') { $link = $Matches[1] } }
    $zip = Join-Path ([IO.Path]::GetTempPath()) ("eyesay-xmp-" + [Guid]::NewGuid().ToString('N') + '.zip')
    try {
        if (-not $link) { throw 'no link' }
        Invoke-WebRequest -Uri $link -OutFile $zip -UseBasicParsing
    } catch {
        Write-Output 'eyesay: could not fetch the XMP sidecars (the link lasts 15 minutes; run again with --xmp)'
        exit 1
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $written = 0; $there = 0; $nofolder = 0
    $archive = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        foreach ($e in $archive.Entries) {
            if (-not $e.FullName.EndsWith('.xmp')) { continue }
            $rel = $e.FullName
            if ([IO.Path]::IsPathRooted($rel) -or ($rel -split '[\\/]') -contains '..') { continue }
            $dest = Join-Path $root ($rel.Replace('/', [IO.Path]::DirectorySeparatorChar))
            if (Test-Path -LiteralPath $dest) { $there++; continue }
            if (-not (Test-Path -LiteralPath (Split-Path -Parent $dest) -PathType Container)) { $nofolder++; continue }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $false)
            $written++
        }
    } finally { $archive.Dispose(); Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue }
    Write-Output "eyesay: $written XMP sidecars written next to your photos ($there already had a .xmp and were left alone, $nofolder skipped: folder not found). Photos were not changed; in Lightroom use Metadata > Read Metadata from File."
}
