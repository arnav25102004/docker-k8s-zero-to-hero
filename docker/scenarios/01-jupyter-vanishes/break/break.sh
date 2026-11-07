#!/usr/bin/env bash
# D01 break: start Jupyter with a misspelled command (start-notebok.py).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

IMAGE="quay.io/jupyter/base-notebook:2026-11-02"

has_exited() { [ "$(docker inspect -f '{{.State.Status}}' d01-jupyter 2>/dev/null)" = "exited" ]; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8101 || die "Port 8101 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$IMAGE" "about 343 MB"

say "Starting Jupyter with the new run command…"
docker run -d --name d01-jupyter --label z2h.scenario=d01 -p 8101:8888 \
  "$IMAGE" start-notebok.py --IdentityProvider.token=change-me-123 >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "the container to stop" 30 has_exited \
  || die "The container never stopped, which is unexpected. Run cleanup.sh and try again."

show_next \
  "You clicked run, Jupyter blinked… and it's gone. Try opening http://localhost:8101: nothing answers." \
  "docker ps"
