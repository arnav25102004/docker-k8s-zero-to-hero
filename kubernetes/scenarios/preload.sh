#!/usr/bin/env bash
# Pull every image the Kubernetes scenarios use, so the stage demo never waits on Wi-Fi.
# The list comes from IMAGES.md (first column of the table). Safe to re-run.
#
# It also loads the images into the cluster of your CURRENT kubectl context:
#   kind-<name>  -> kind load docker-image <img> --name <name>
#   minikube     -> minikube image load <img>
# Any other context (Docker Desktop, Killercoda, iximiuz, ...): images are only pulled
# to Docker; the cluster downloads what it needs the first time a Pod starts.
# Check which cluster that is first:  kubectl config current-context
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
LIST="$DIR/IMAGES.md"

if ! docker info >/dev/null 2>&1; then
  echo "Docker isn't running. Start Docker Desktop (or the Docker service) and try again."
  exit 1
fi
[ -f "$LIST" ] || { echo "Cannot find $LIST"; exit 1; }

# Table rows look like: | `image:tag` | size | used by |  -> print "image:tag"
IMAGES=$(awk -F'|' '
  /^\| *`/ {
    img = $2
    gsub(/[ `]/, "", img)
    if (img != "") print img
  }' "$LIST")

# Where do the images go besides Docker?
TARGET="none"
CLUSTER=""
CTX=""
if command -v kubectl >/dev/null 2>&1; then
  CTX=$(kubectl config current-context 2>/dev/null || true)
fi
case "$CTX" in
  kind-*)   TARGET="kind"; CLUSTER="${CTX#kind-}" ;;
  minikube) TARGET="minikube" ;;
esac

case "$TARGET" in
  kind)     printf 'Current context: %s -> images will also be loaded into the kind cluster "%s".\n' "$CTX" "$CLUSTER" ;;
  minikube) printf 'Current context: %s -> images will also be loaded into minikube.\n' "$CTX" ;;
  *)        if [ -n "$CTX" ]; then
              printf 'Current context: %s -> images are pulled to Docker only (this cluster downloads them itself).\n' "$CTX"
            else
              echo "No kubectl context found -> images are pulled to Docker only."
            fi ;;
esac
echo "Not the cluster you meant? Stop now (Ctrl+C) and check: kubectl config current-context"
echo

total=0
failed=0
for ref in $IMAGES; do
  total=$((total + 1))
  printf '⬇️  %s\n' "$ref"
  if ! docker pull -q "$ref" >/dev/null 2>&1; then
    printf '❌ %s (pull failed: check the Wi-Fi and run this again)\n' "$ref"
    failed=$((failed + 1))
    continue
  fi
  case "$TARGET" in
    kind)
      if ! command -v kind >/dev/null 2>&1; then
        printf '❌ %s (pulled, but the kind command is missing, so it was not loaded)\n' "$ref"
        failed=$((failed + 1))
      elif kind load docker-image "$ref" --name "$CLUSTER" >/dev/null 2>&1; then
        printf '✅ %s (pulled, loaded into kind "%s")\n' "$ref" "$CLUSTER"
      else
        printf '❌ %s (pulled, but loading into kind "%s" failed)\n' "$ref" "$CLUSTER"
        failed=$((failed + 1))
      fi ;;
    minikube)
      if ! command -v minikube >/dev/null 2>&1; then
        printf '❌ %s (pulled, but the minikube command is missing, so it was not loaded)\n' "$ref"
        failed=$((failed + 1))
      elif minikube image load "$ref" >/dev/null 2>&1; then
        printf '✅ %s (pulled, loaded into minikube)\n' "$ref"
      else
        printf '❌ %s (pulled, but loading into minikube failed)\n' "$ref"
        failed=$((failed + 1))
      fi ;;
    *)
      printf '✅ %s\n' "$ref" ;;
  esac
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
if [ "$TARGET" = "none" ]; then
  echo "✅ All images are on this machine."
else
  echo "✅ All images are on this machine and in the cluster."
fi
