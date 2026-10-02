#!/bin/sh
# EyeSay: copy a sorted photo job into <folder>/EyeSay/<label>/ (originals untouched).
# usage: sh organize.sh <labels CSV link> <folder> [label=folder name ...]
# Delete <folder>/EyeSay to undo; running it again skips what is already copied.
set -u
CSV_URL="${1:-}"; DIR="${2:-}"
[ -n "$CSV_URL" ] && [ -d "$DIR" ] || { echo "usage: sh organize.sh <labels CSV link> <folder> [label=name ...]" >&2; exit 2; }
shift 2
TMP=$(mktemp "${TMPDIR:-/tmp}/eyesay-org.XXXXXX") || exit 1
curl -fsS "$CSV_URL" -o "$TMP.csv" || { echo "eyesay: could not fetch the sorting (links last 15 minutes; sort again)" >&2; rm -f "$TMP" "$TMP.csv"; exit 1; }
TAB=$(printf '\t')
# RFC 4180 fields (quotes, commas, spaces, any script) -> "label<TAB>photo"; names with a tab or newline -> ODD
LC_ALL=C awk 'NR == 1 { next }
{ line = $0
  while (gsub(/"/, "\"", line) % 2 == 1 && (getline more) > 0) line = line "\n" more
  n = 0; f = ""; q = 0
  for (i = 1; i <= length(line); i++) {
    c = substr(line, i, 1)
    if (q) { if (c == "\"") { if (substr(line, i + 1, 1) == "\"") { f = f c; i++ } else q = 0 } else f = f c }
    else if (c == "\"") q = 1
    else if (c == ",") { fld[++n] = f; f = "" }
    else if (c != "\r") f = f c
  }
  fld[++n] = f
  if (fld[1] ~ /[\t\n]/ || fld[2] ~ /[\t\n]/) print "ODD"; else print fld[2] "\t" fld[1] }' "$TMP.csv" > "$TMP"
copied=0; there=0; missing=0; odd=0
: > "$TMP.done"
while IFS="$TAB" read -r label photo; do
  [ "$label" = ODD ] && [ -z "$photo" ] && { odd=$((odd + 1)); continue; }
  case "$photo" in /*|../*|*/../*|..) odd=$((odd + 1)); continue ;; esac
  name=$label
  for pair in "$@"; do [ "${pair%%=*}" = "$label" ] && name=${pair#*=}; done
  name=$(printf %s "$name" | tr '/' '-')
  case "$name" in ""|.|..) name=unnamed ;; esac
  src="$DIR/$photo"; dest="$DIR/EyeSay/$name/$photo"
  if [ -e "$dest" ]; then there=$((there + 1)); echo "$name" >> "$TMP.done"; continue; fi
  if [ ! -f "$src" ]; then missing=$((missing + 1)); continue; fi
  mkdir -p "$(dirname "$dest")" && cp -p "$src" "$dest" && { copied=$((copied + 1)); echo "$name" >> "$TMP.done"; }
done < "$TMP"
counts=$(sort "$TMP.done" | uniq -c | awk '{ n = $1; $1 = ""; sub(/^ /, ""); printf "%s%s %d", sep, $0, n; sep = ", " }')
echo "eyesay: $copied copied into $DIR/EyeSay ($there already there, $missing not found, $odd skipped): $counts"
echo "Originals were not moved or changed. Delete $DIR/EyeSay to undo."
rm -f "$TMP" "$TMP.csv" "$TMP.done"
