#!/usr/bin/env bash
# D07 fix: give uid 1000 / gid 100 (jovyan) ownership of everything in the volume, then restart Jupyter.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

IMAGE="quay.io/jupyter/base-notebook:2026-11-02"
HELPER="busybox:1.36"

jupyter_up() { curl -s -f -o /dev/null --max-time 2 "http://localhost:8107/api/status?token=change-me-123"; }

need_docker
ensure_image "$IMAGE" "about 343 MB"
ensure_image "$HELPER" "about 2 MB"
docker volume inspect d07-notebooks >/dev/null 2>&1 \
  || die "The volume d07-notebooks isn't there. Run ../break/break.sh first."
docker inspect d07-jupyter >/dev/null 2>&1 \
  || die "The container d07-jupyter isn't there. Run ../break/break.sh first."

say "Giving the notebooks to jovyan (uid 1000, gid 100) with a one-off container…"
docker run --rm --label z2h.scenario=d07 -v d07-notebooks:/data "$HELPER" chown -R 1000:100 /data \
  || die "The chown container failed. Is Docker healthy?"

say "Restarting Jupyter…"
docker restart d07-jupyter >/dev/null || die "Could not restart d07-jupyter."
wait_for "Jupyter to come back" 60 jupyter_up \
  || die "Jupyter didn't come back in time. Is Docker healthy?"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker exec d07-jupyter touch /home/jovyan/work/assignments/test.ipynb"
