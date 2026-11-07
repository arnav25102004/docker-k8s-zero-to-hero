#!/usr/bin/env bash
# D08 fix: same IT-Tools, but the health check probes port 80, where the app really listens.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

TOOLS_IMAGE="corentinth/it-tools:2024.10.22-7ca5933"

is_healthy() { [ "$(docker inspect -f '{{.State.Health.Status}}' d08-tools 2>/dev/null)" = "healthy" ]; }

need_docker
say "Recreating IT-Tools with a health check that probes port 80"
docker rm -f d08-tools >/dev/null 2>&1
docker run -d --name d08-tools --label z2h.scenario=d08 -p 8108:80 \
  --health-cmd 'wget -qO- http://127.0.0.1:80/ || exit 1' --health-interval 3s --health-retries 2 \
  "$TOOLS_IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "Docker to report the container healthy" 60 is_healthy \
  || die "IT-Tools didn't become healthy in time. Check: docker inspect -f '{{json .State.Health}}' d08-tools"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker ps"
