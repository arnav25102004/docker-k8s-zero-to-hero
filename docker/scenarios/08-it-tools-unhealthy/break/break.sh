#!/usr/bin/env bash
# D08 break: run IT-Tools on host port 8108 with a health check that probes the wrong port (8080).
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

say "Starting IT-Tools on port 8108, with a health check…"
docker run -d --name d08-tools --label z2h.scenario=d08 -p 8108:80 \
  --health-cmd 'wget -qO- http://127.0.0.1:8080/ || exit 1' --health-interval 3s --health-retries 2 \
  "$TOOLS_IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "IT-Tools to answer on port 8108" 60 app_up \
  || die "IT-Tools didn't come up in time. Run cleanup.sh and try again."
wait_for "Docker to give its verdict" 60 is_unhealthy \
  || die "Unexpected health state. Run cleanup.sh and try again."

show_next \
  "Open http://localhost:8108: the app works. But Docker says the container is sick." \
  "docker ps"
