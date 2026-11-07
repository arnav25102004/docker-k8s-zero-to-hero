#!/usr/bin/env bash
# D10 fix: .dockerignore excludes only *.test.js and node_modules/, so the build succeeds; then run it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

app_answers() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://localhost:8110)" = "200" ]; }

need_docker
cd "$HERE" || die "Could not enter $HERE"
say "Building the QR app: docker build -t d10-qr:1.0 ."
docker build --label z2h.scenario=d10 -t d10-qr:1.0 . || die "The build failed. Did you run break.sh first? Try: docker build -t d10-qr:1.0 ."
docker rm -f d10-qr >/dev/null 2>&1
say "Starting it: docker run -d --name d10-qr -p 8110:80 d10-qr:1.0"
docker run -d --name d10-qr --label z2h.scenario=d10 -p 8110:80 d10-qr:1.0 >/dev/null \
  || die "docker run failed. Is port 8110 free?"

wait_for "the QR app to answer on port 8110" 30 app_answers \
  || die "The app didn't answer. Check: docker logs d10-qr"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker images d10-qr"
