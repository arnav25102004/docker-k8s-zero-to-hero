#!/usr/bin/env bash
# D01 fix: same command, spelled correctly (start-notebook.py).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

IMAGE="quay.io/jupyter/base-notebook:2026-11-02"

jupyter_up() {
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 'http://localhost:8101/api/status?token=change-me-123')" = "200" ]
}

need_docker
say "Recreating the container with the correct command: start-notebook.py"
docker rm -f d01-jupyter >/dev/null 2>&1
docker run -d --name d01-jupyter --label z2h.scenario=d01 -p 8101:8888 \
  "$IMAGE" start-notebook.py --IdentityProvider.token=change-me-123 >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "Jupyter to answer on port 8101" 90 jupyter_up \
  || die "Jupyter didn't come up in time. Check: docker logs d01-jupyter"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker ps" \
  "Then open http://localhost:8101/lab?token=change-me-123"
