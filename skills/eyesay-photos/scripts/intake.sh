#!/bin/sh
# EyeSay: send a folder's photos to a photo job; prints the job's result last.
# usage: sh intake.sh <job URL> <upload token> <folder> [--xmp | --xmp-suggestions]   (from prepare_upload)
# --xmp: afterwards write each photo's tags as an XMP sidecar (<name>.xmp) next to the original,
#        for Lightroom, Bridge and Photo Mechanic; never over an existing .xmp, photos never touched.
#        --xmp-suggestions adds the tags EyeSay is less sure of.
set -u
XMP=""; n=$#
while [ "$n" -gt 0 ]; do
  a="$1"; shift; n=$((n - 1))
  case "$a" in --xmp) XMP=1 ;; --xmp-suggestions) XMP=all ;; *) set -- "$@" "$a" ;; esac
done
URL="${1:-}"; TOKEN="${2:-}"; DIR="${3:-}"
[ -n "$URL" ] && [ -n "$TOKEN" ] && [ -d "$DIR" ] || { echo "usage: sh intake.sh <job URL> <token> <folder> [--xmp]" >&2; exit 2; }
LOG=$(mktemp "${TMPDIR:-/tmp}/eyesay-log.XXXXXX") || exit 1
STOP="$LOG.stop"
export URL TOKEN LOG STOP
cd "$DIR" || exit 2
find . -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \
       -o -iname '*.heif' -o -iname '*.webp' \) ! -path '*/.*' ! -path './EyeSay/*' -print0 2>/dev/null |
xargs -0 -n 1 -P "${EYESAY_PARALLEL:-4}" sh -c '
  f="$1"; [ -e "$STOP" ] && { echo skipped >> "$LOG"; exit 0; }
  up="$f"; tmp=""
  if command -v sips >/dev/null 2>&1; then
    tmp=$(mktemp "${TMPDIR:-/tmp}/eyesay.XXXXXX") && mv "$tmp" "$tmp.jpg" && tmp="$tmp.jpg"
    sips -Z 896 -s format jpeg -s formatOptions 85 "$f" --out "$tmp" >/dev/null 2>&1 && up="$tmp"
  fi
  name=$(printf %s "${f#./}" | od -An -v -tx1 | tr -d " \n" | sed "s/../%&/g")
  tries=0
  while :; do
    out=$(curl -sS -w "
%{http_code}" -X POST -H "X-Intake-Token: $TOKEN" -H "X-File-Name: $name" \
          -H "Content-Type: application/octet-stream" --data-binary @"$up" "$URL" 2>/dev/null)
    code=$(printf %s "$out" | tail -n 1)
    case "$code" in
      429|503) case "$out" in *\"stopped\"*) touch "$STOP"; break ;; esac
               tries=$((tries + 1)); [ "$tries" -ge 10 ] && break; sleep 2 ;;
      *) break ;;
    esac
  done
  [ -n "$tmp" ] && rm -f "$tmp"
  case "$code" in
    200) case "$out" in *\"duplicate\"*) echo duplicate ;; *) echo ok ;; esac ;;
    401) touch "$STOP"; echo expired ;;
    429) case "$out" in *\"stopped\"*) echo stopped ;; *) echo busy ;; esac ;;
    *) echo failed ;;
  esac >> "$LOG"
' _
n() { grep -c "^$1\$" "$LOG" 2>/dev/null || true; }
line="eyesay: $(n ok) sent and tagged, $(n duplicate) already in the job, $(n failed) failed"
[ "$(n busy)" -gt 0 ] && line="$line, $(n busy) busy (run again)"
[ "$(n stopped)" -gt 0 ] && line="$line; STOPPED: the account's photos are used up ($(n skipped) not sent)"
[ "$(n expired)" -gt 0 ] && line="$line; STOPPED: the upload token lapsed, ask for a new one with prepare_upload and run again ($(n skipped) not sent)"
echo "$line"
bad=$(( $(n stopped) + $(n expired) ))
rm -f "$LOG" "$STOP"
if [ -z "$XMP" ]; then
  [ "$bad" -eq 0 ] && curl -sS -H "X-Intake-Token: $TOKEN" "$URL/summary" 2>/dev/null
  [ "$bad" -eq 0 ]
  exit
fi
[ "$bad" -eq 0 ] || { echo "eyesay: no XMP sidecars written (the run stopped early; run it again with --xmp)"; exit 1; }
summary=$(curl -sS -H "X-Intake-Token: $TOKEN" "$URL/summary?xmp=$XMP" 2>/dev/null)
printf '%s\n' "$summary"
link=$(printf '%s\n' "$summary" | sed -n 's/^XMP sidecars.*): //p' | head -n 1)
X=$(mktemp -d "${TMPDIR:-/tmp}/eyesay-xmp.XXXXXX") || exit 1
if [ -z "$link" ] || ! curl -fsS "$link" -o "$X/xmp.zip" 2>/dev/null; then
  echo "eyesay: could not fetch the XMP sidecars (the link lasts 15 minutes; run again with --xmp)"; rm -rf "$X"; exit 1
fi
command -v unzip >/dev/null 2>&1 || { echo "eyesay: unzip not found; no XMP sidecars written. Download and unzip into the folder: $link"; rm -rf "$X"; exit 1; }
mkdir "$X/out" && unzip -q "$X/xmp.zip" -d "$X/out" 2>/dev/null || { echo "eyesay: the XMP download could not be unpacked"; rm -rf "$X"; exit 1; }
written=0; there=0; nofolder=0
( cd "$X/out" && find . -type f -name '*.xmp' ! -name '.*' ) > "$X/list"
while IFS= read -r f; do
  rel=${f#./}
  case "$rel" in /*|../*|*/../*|..) continue ;; esac
  dest="./$rel"
  if [ -e "$dest" ] || [ -L "$dest" ]; then there=$((there + 1)); continue; fi
  [ -d "$(dirname "$dest")" ] || { nofolder=$((nofolder + 1)); continue; }
  cp -n "$X/out/$rel" "$dest" 2>/dev/null && written=$((written + 1))
done < "$X/list"
rm -rf "$X"
echo "eyesay: $written XMP sidecars written next to your photos ($there already had a .xmp and were left alone, $nofolder skipped: folder not found). Photos were not changed; in Lightroom use Metadata > Read Metadata from File."
