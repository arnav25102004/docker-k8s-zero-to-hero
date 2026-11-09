#!/usr/bin/env bash
# D08 break: copy break/ into work/, build the image, run it, and wait for Docker's verdict.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

TOOLS_IMAGE="corentinth/it-tools:2024.10.22-7ca5933"

app_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8108)" = "200" ]; }
is_unhealthy() { [ "$(docker inspect -f '{{.State.Health.Status}}' d08-tools 2>/dev/null)" = "unhealthy" ]; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8108 || die "Port 8108 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$TOOLS_IMAGE" "about 24 MB"

cd "$HERE/.." || die "Could not enter the scenario folder"
say "The night before registration opens. Building the tools page from work/Dockerfile (a fresh copy of break/):"
prepare_work "$HERE/../break"
run_shown docker build -t d08-tools:1.0 work || die "The build failed. Read the error above."
run_shown docker run -d --name d08-tools -p 8108:80 d08-tools:1.0 \
  || die "docker run failed. Is port 8108 free?"

wait_for "IT-Tools to answer on port 8108" 60 app_up \
  || die "IT-Tools didn't come up in time. Check: docker logs d08-tools"
# Docker needs interval x retries (3 s x 2) of failed checks, so about 6-9 seconds.
wait_for "Docker to give its verdict (about 10 seconds)" 60 is_unhealthy \
  || die "Unexpected health state. Run cleanup.sh and try again."

show_next \
  "Open http://localhost:8108 (playground: the port 8108 URL): the app works. But Docker says the container is sick." \
  "docker ps --filter name=d08-tools"
