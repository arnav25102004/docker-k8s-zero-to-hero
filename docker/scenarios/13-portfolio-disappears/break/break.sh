#!/usr/bin/env bash
# D13 break: a bind mount of dev-notes/ covers /usr/share/nginx/html, hiding the website baked into the image.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

BASE_IMAGE="nginx:1.27.5-alpine"

# nginx must be up and answering (a 403 is an answer; connection refused is not).
nginx_answers() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://localhost:8113)" != "000" ]; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8113 || die "Port 8113 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$BASE_IMAGE" "about 23 MB"

say "Building Priya's portfolio: docker build -t d13-site:1.0 break"
cd "$HERE" || die "Could not enter $HERE"
docker build -q --label z2h.scenario=d13 -t d13-site:1.0 . >/dev/null \
  || die "The build failed. Try: docker build -t d13-site:1.0 break"
say "Starting it with live edits: docker run -d --name d13-site -p 8113:80 -v $HERE/dev-notes:/usr/share/nginx/html d13-site:1.0"
docker run -d --name d13-site --label z2h.scenario=d13 -p 8113:80 \
  -v "$HERE/dev-notes:/usr/share/nginx/html" d13-site:1.0 >/dev/null \
  || die "docker run failed. Is port 8113 free?"

wait_for "nginx to start on port 8113" 30 nginx_answers \
  || die "The container didn't start. Check: docker logs d13-site"

scene_set
