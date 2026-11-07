#!/usr/bin/env bash
# D04 fix: same VS Code, recreated with -e PASSWORD=change-me-123.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

IMAGE="codercom/code-server:4.145.2"

vscode_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8104/healthz)" = "200" ]; }

need_docker
say "Recreating VS Code with PASSWORD=change-me-123 passed in"
docker rm -f d04-vscode >/dev/null 2>&1
docker run -d --name d04-vscode --label z2h.scenario=d04 -p 8104:8080 -e PASSWORD=change-me-123 "$IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"
wait_for "VS Code to answer on port 8104" 90 vscode_up \
  || die "VS Code didn't come up in time. Check: docker logs d04-vscode"

show_next "✅ Fixed. Now verify it yourself:" \
  "Open http://localhost:8104 and log in with change-me-123" \
  "docker exec d04-vscode printenv PASSWORD"
