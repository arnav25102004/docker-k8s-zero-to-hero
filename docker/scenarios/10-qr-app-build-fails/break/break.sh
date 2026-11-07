#!/usr/bin/env bash
# D10 break: .dockerignore excludes *.js, so qrcode.min.js never reaches the build and docker build fails.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

BASE_IMAGE="nginx:1.27.5-alpine"

need_docker
bash "$HERE/../cleanup.sh"
port_free 8110 || die "Port 8110 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$BASE_IMAGE" "about 23 MB"

say "Building the QR app: docker build -t d10-qr:1.0 ."
cd "$HERE" || die "Could not enter $HERE"
docker build --label z2h.scenario=d10 -t d10-qr:1.0 .
say "Starting it: docker run --pull never -d --name d10-qr -p 8110:80 d10-qr:1.0"
docker run --pull never -d --name d10-qr --label z2h.scenario=d10 -p 8110:80 d10-qr:1.0

show_next \
  "Both commands above failed: the build stopped with an error, and there is no image to run." \
  "docker build -t d10-qr:1.0 ."
