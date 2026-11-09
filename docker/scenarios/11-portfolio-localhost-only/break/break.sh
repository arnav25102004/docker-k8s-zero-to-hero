#!/usr/bin/env bash
# D11 break: the portfolio server binds 127.0.0.1 inside the container, so the published port 8111 can't reach it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

BASE_IMAGE="python:3.12-alpine"

# The server must be up inside the container (that is what makes this bug confusing).
up_inside() { docker exec d11-portfolio wget -qO- http://127.0.0.1:8000 >/dev/null 2>&1; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8111 || die "Port 8111 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$BASE_IMAGE" "about 19 MB"

say "Building Priya's portfolio: docker build -t d11-portfolio:1.0 break"
cd "$HERE" || die "Could not enter $HERE"
docker build -q --label z2h.scenario=d11 -t d11-portfolio:1.0 . >/dev/null \
  || die "The build failed. Try: docker build -t d11-portfolio:1.0 break"
say "Starting it: docker run -d --name d11-portfolio -p 8111:8000 d11-portfolio:1.0"
docker run -d --name d11-portfolio --label z2h.scenario=d11 -p 8111:8000 d11-portfolio:1.0 >/dev/null \
  || die "docker run failed. Is port 8111 free?"

wait_for "the portfolio container to start" 30 up_inside \
  || die "The container didn't start. Check: docker logs d11-portfolio"

show_next \
  "The container is running. Open http://localhost:8111 (playground: the port 8111 URL): the page does not load." \
  "curl localhost:8111"
