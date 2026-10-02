# EyeSay: copy a sorted photo job into <folder>\EyeSay\<label>\ (originals untouched; Windows).
# usage: & ([scriptblock]::Create((Get-Content -Raw <path>\organize.ps1))) <labels CSV link> <folder> [label=folder name ...]
# Delete <folder>\EyeSay to undo; running it again skips what is already copied.
param([Parameter(Mandatory = $true)][string]$CsvUrl,
      [Parameter(Mandatory = $true)][string]$Dir,
      [Parameter(ValueFromRemainingArguments = $true)][string[]]$Names)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { Write-Error "eyesay: no such folder: $Dir"; exit 2 }
$map = @{}
foreach ($p in $Names) { $i = $p.IndexOf('='); if ($i -gt 0) { $map[$p.Substring(0, $i)] = $p.Substring($i + 1) } }
try { $rows = (Invoke-WebRequest -Uri $CsvUrl -UseBasicParsing).Content | ConvertFrom-Csv }
catch { Write-Error "eyesay: could not fetch the sorting (links last 15 minutes; sort again)"; exit 1 }
$copied = 0; $there = 0; $missing = 0; $odd = 0; $count = @{}
foreach ($r in $rows) {
    $photo = $r.photo; $label = $r.label
    if ([IO.Path]::IsPathRooted($photo) -or ($photo -split '[\\/]') -contains '..') { $odd++; continue }
    $name = if ($map.ContainsKey($label)) { $map[$label] } else { $label }
    $name = $name.Replace('/', '-').Replace('\', '-')
    if ($name -in @('', '.', '..')) { $name = 'unnamed' }
    $src = Join-Path $Dir $photo
    $dest = Join-Path (Join-Path (Join-Path $Dir 'EyeSay') $name) $photo
    if (Test-Path -LiteralPath $dest) { $there++; $count[$name] = 1 + $count[$name]; continue }
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { $missing++; continue }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dest
    $copied++; $count[$name] = 1 + $count[$name]
}
$counts = ($count.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name) $($_.Value)" }) -join ', '
Write-Output "eyesay: $copied copied into $(Join-Path $Dir 'EyeSay') ($there already there, $missing not found, $odd skipped): $counts"
Write-Output "Originals were not moved or changed. Delete $(Join-Path $Dir 'EyeSay') to undo."
