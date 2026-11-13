#!/usr/bin/env bash
# D04 break: copy app.env into work/ and start VS Code (code-server) on host port 8104 with it.
# Every Docker command is printed before it runs, exactly as you could type it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCEN="$(dirname "$HERE")"
# shellcheck source=/dev/null
source "$SCEN/../_lib.sh"
refuse_if_in_work "$HERE"

IMAGE="codercom/code-server:4.145.2"

vscode_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8104/healthz)" = "200" ]; }

need_docker
bash "$SCEN/cleanup.sh" >/dev/null
port_free 8104 || die "Port 8104 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$IMAGE" "about 380 MB"

prepare_work "$HERE"
cd "$SCEN" || die "Could not enter $SCEN"

run_shown_quiet docker run -d --name d04-vscode -p 8104:8080 --env-file work/app.env "$IMAGE" \
  || die "docker run failed. Is Docker healthy?"
wait_for "VS Code to answer on port 8104" 90 vscode_up \
  || die "VS Code didn't come up in time. Run ./cleanup.sh and try again."

scene_set
