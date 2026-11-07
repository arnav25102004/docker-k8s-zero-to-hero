#!/usr/bin/env bash
# D04 break: start VS Code in the browser (code-server) on host port 8104, without PASSWORD.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

IMAGE="codercom/code-server:4.145.2"

vscode_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8104/healthz)" = "200" ]; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8104 || die "Port 8104 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$IMAGE" "about 380 MB"

say "Starting VS Code in the browser on port 8104…"
docker run -d --name d04-vscode --label z2h.scenario=d04 -p 8104:8080 "$IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"
wait_for "VS Code to answer on port 8104" 90 vscode_up \
  || die "VS Code didn't come up in time. Run cleanup.sh and try again."

show_next \
  "VS Code is running at http://localhost:8104 and asks for a password. Type: change-me-123" \
  "Then see what happens, and run: docker logs d04-vscode"
