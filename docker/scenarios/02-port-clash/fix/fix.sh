#!/usr/bin/env bash
# D02 fix: same IT-Tools, but published on host port 8202 (the container port stays 80).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

TOOLS_IMAGE="corentinth/it-tools:2024.10.22-7ca5933"

tools_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8202)" = "200" ]; }

need_docker
say "Recreating IT-Tools on host port 8202 (inside the container it is still port 80)"
docker rm -f d02-tools >/dev/null 2>&1
docker run -d --name d02-tools --label z2h.scenario=d02 -p 8202:80 "$TOOLS_IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "IT-Tools to answer on port 8202" 60 tools_up \
  || die "IT-Tools didn't come up in time. Check: docker logs d02-tools"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker ps --format '{{.Names}}  {{.Ports}}'" \
  "Then open http://localhost:8102 and http://localhost:8202"
