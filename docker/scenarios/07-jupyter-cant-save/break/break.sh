#!/usr/bin/env bash
# D07 break: an "old backup job" (root) creates work/assignments, then Jupyter (uid 1000) starts.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

IMAGE="quay.io/jupyter/base-notebook:2026-11-02"
HELPER="busybox:1.36"

jupyter_up() { curl -s -f -o /dev/null --max-time 2 "http://localhost:8107/api/status?token=change-me-123"; }
cannot_save() { ! docker exec d07-jupyter touch /home/jovyan/work/assignments/test.ipynb; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8107 || die "Port 8107 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$IMAGE" "about 343 MB"
ensure_image "$HELPER" "about 2 MB"

say "Creating the notebooks volume, and letting an old backup job (running as root) set it up…"
docker volume create --label z2h.scenario=d07 d07-notebooks >/dev/null \
  || die "Could not create the volume. Is Docker healthy?"
# The volume's top folder belongs to uid 1000 (like a normal Jupyter work folder);
# the "assignments" folder inside it is created by root, mode 755.
docker run --rm --label z2h.scenario=d07 -v d07-notebooks:/data "$HELPER" \
  sh -c 'chown 1000:100 /data && mkdir /data/assignments && chown 0:0 /data/assignments && chmod 755 /data/assignments' \
  || die "The backup-job container failed. Is Docker healthy?"

say "Starting Jupyter…"
docker run -d --name d07-jupyter --label z2h.scenario=d07 -p 8107:8888 \
  -v d07-notebooks:/home/jovyan/work \
  "$IMAGE" start-notebook.py --IdentityProvider.token=change-me-123 >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "Jupyter to start" 60 jupyter_up \
  || die "Jupyter didn't start in time. Run cleanup.sh and try again."
wait_for "the setup to settle" 10 cannot_save \
  || die "Something is off with the setup. Run cleanup.sh and try again."

show_next \
  "Jupyter is up: open http://localhost:8107/lab?token=change-me-123 (playground: the port 8107 URL + /lab?token=change-me-123). In the file browser open work, then assignments, and try to create or save a notebook there. Jupyter shows a permission error." \
  "Look at the error, then ask the container who it is:  docker exec d07-jupyter id"
