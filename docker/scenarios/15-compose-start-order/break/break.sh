#!/usr/bin/env bash
# D15 break: depends_on starts db first but doesn't wait for it, so the app tries Postgres while it is still setting up.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

app_exited() { [ "$(docker compose -p d15 ps -a app --format '{{.State}} {{.ExitCode}}' 2>/dev/null)" = "exited 1" ]; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8115 || die "Port 8115 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "postgres:16.15-alpine" "about 116 MB"
ensure_image "python:3.12-alpine" "about 19 MB"

say "Starting the stack: docker compose -p d15 up -d"
docker compose -p d15 -f "$HERE/compose.yaml" up -d \
  || die "docker compose up failed. Try: docker compose -p d15 -f $HERE/compose.yaml up"
wait_for "the app to give up" 30 app_exited \
  || die "The app didn't exit as expected. Check: docker compose -p d15 ps -a"

scene_set
