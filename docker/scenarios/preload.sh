#!/usr/bin/env bash
# Pull every image the Docker scenarios use, so the stage demo never waits on Wi-Fi.
# The list comes from IMAGES.md (the table: `image` | `tag`). Safe to re-run.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
LIST="$DIR/IMAGES.md"

if ! docker info >/dev/null 2>&1; then
  echo "Docker isn't running. Start Docker Desktop (or the Docker service) and try again."
  exit 1
fi
[ -f "$LIST" ] || { echo "Cannot find $LIST"; exit 1; }

# Table rows look like: | `image` | `tag` | ...  -> print "image:tag"
IMAGES=$(awk -F'|' '
  /^\| *`/ {
    img = $2; tag = $3
    gsub(/[ `]/, "", img); gsub(/[ `]/, "", tag)
    if (img != "" && tag != "") print img ":" tag
  }' "$LIST")

total=0
failed=0
for ref in $IMAGES; do
  total=$((total + 1))
  printf '⬇️  %s\n' "$ref"
  if docker pull -q "$ref" >/dev/null 2>&1; then
    printf '✅ %s\n' "$ref"
  else
    printf '❌ %s (pull failed: check the Wi-Fi and run this again)\n' "$ref"
    failed=$((failed + 1))
  fi
done

echo
if [ "$total" -eq 0 ]; then
  echo "❌ No images found in $LIST"
  exit 1
fi
printf '%s of %s images ready.\n' "$((total - failed))" "$total"
if [ "$failed" -gt 0 ]; then
  printf '❌ %s failed.\n' "$failed"
  exit 1
fi
echo "✅ All images are on this machine."
