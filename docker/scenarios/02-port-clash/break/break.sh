#!/usr/bin/env bash
# D02 break: the shortcut for the two `docker run` lines in the README.
# It prints every Docker command before it runs it, exactly as you would type it.
# There is nothing to edit in this scenario, so there is no work/ folder.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

DRAW_IMAGE="excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9"
TOOLS_IMAGE="corentinth/it-tools:2024.10.22-7ca5933"

draw_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8102)" = "200" ]; }
tools_created() { [ "$(docker inspect -f '{{.State.Status}}' d02-tools 2>/dev/null)" = "created" ]; }
# pull_if_missing IMAGE SIZE: show the pull command only when the image is not here yet.
pull_if_missing() {
  docker image inspect "$1" >/dev/null 2>&1 && return 0
  say "Downloading $1 ($2, first time only)"
  run_shown docker pull "$1" || die "Could not download $1. Check your internet connection and try again."
}

need_docker
bash "$HERE/../cleanup.sh" >/dev/null
port_free 8102 || die "Port 8102 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
port_free 8202 || die "Port 8202 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
pull_if_missing "$DRAW_IMAGE" "about 44 MB"
pull_if_missing "$TOOLS_IMAGE" "about 24 MB"

say "Line 1: start Excalidraw"
run_shown docker run -d --name d02-draw -p 8102:80 "$DRAW_IMAGE" \
  || die "docker run failed. Is Docker healthy?"
wait_for "Excalidraw to answer on port 8102" 60 draw_up \
  || die "Excalidraw didn't come up in time. Run cleanup.sh and try again."

say "Line 2: start IT-Tools"
run_shown docker run -d --name d02-tools -p 8102:80 "$TOOLS_IMAGE" || true

wait_for "IT-Tools to be created" 15 tools_created \
  || die "Unexpected state for d02-tools. Run cleanup.sh and try again."

show_next \
  "Excalidraw works at http://localhost:8102, but the error above says IT-Tools could not start." \
  "docker ps -a"
