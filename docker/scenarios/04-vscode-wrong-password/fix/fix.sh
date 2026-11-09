#!/usr/bin/env bash
# D04 fix: copy the corrected app.env into work/ and recreate the container with it.
# Every Docker command is printed before it runs, exactly as you could type it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCEN="$(dirname "$HERE")"
# shellcheck source=/dev/null
source "$SCEN/../_lib.sh"

IMAGE="codercom/code-server:4.145.2"

vscode_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8104/healthz)" = "200" ]; }

need_docker
prepare_work "$HERE"
cd "$SCEN" || die "Could not enter $SCEN"

run_shown_quiet docker rm -f d04-vscode
run_shown_quiet docker run -d --name d04-vscode -p 8104:8080 --env-file work/app.env "$IMAGE" \
  || die "docker run failed. Is Docker healthy?"
wait_for "VS Code to answer on port 8104" 90 vscode_up \
  || die "VS Code didn't come up in time. Check: docker logs d04-vscode"

show_next "✅ Fixed. Now verify it yourself:" \
  "Open http://localhost:8104 and log in with change-me-123" \
  "docker exec d04-vscode printenv PASSWORD"
