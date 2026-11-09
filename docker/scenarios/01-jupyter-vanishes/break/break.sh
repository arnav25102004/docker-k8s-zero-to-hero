#!/usr/bin/env bash
# D01 break: build and run the Dockerfile in work/. Every Docker command is printed first.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"
refuse_if_in_work "$HERE"

IMAGE="quay.io/jupyter/base-notebook:2026-11-02"

has_exited() { [ "$(docker inspect -f '{{.State.Status}}' d01-jupyter 2>/dev/null)" = "exited" ]; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8101 || die "Port 8101 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$IMAGE" "about 343 MB"

prepare_work "$HERE"
cd "$HERE/.." || die "Could not enter the scenario folder"

run_shown docker build -t d01-jupyter:1.0 work \
  || die "The build failed. Read the message above, then try again."
run_shown_quiet docker run -d --name d01-jupyter -p 8101:8888 d01-jupyter:1.0 \
  || die "docker run failed. Is port 8101 free?"

wait_for "the container to stop" 30 has_exited \
  || die "The container never stopped, which is unexpected. Run cleanup.sh and try again."

show_next \
  "You clicked run, Jupyter blinked… and it's gone. Try opening http://localhost:8101: nothing answers." \
  "docker ps"
