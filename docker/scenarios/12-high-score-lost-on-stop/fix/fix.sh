#!/usr/bin/env bash
# D12 fix: rebuild with the exec-form CMD so Python is PID 1 and receives SIGTERM.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

app_answers() { curl -s -o /dev/null --max-time 2 http://localhost:8112/api/scores; }

need_docker
cd "$HERE" || die "Could not enter $HERE"
say "Rebuilding with the fixed Dockerfile: docker build -t d12-game:1.0 fix"
docker build -q --label z2h.scenario=d12 -t d12-game:1.0 . >/dev/null \
  || die "The build failed. Try: docker build -t d12-game:1.0 fix"
docker rm -f d12-game >/dev/null 2>&1
docker volume create --label z2h.scenario=d12 d12-data >/dev/null || die "Could not create the volume d12-data."
say "Starting it again: docker run -d --name d12-game -p 8112:8000 -v d12-data:/data d12-game:1.0"
docker run -d --name d12-game --label z2h.scenario=d12 -p 8112:8000 -v d12-data:/data d12-game:1.0 >/dev/null \
  || die "docker run failed. Is port 8112 free?"

wait_for "the game server to start" 30 app_answers \
  || die "The server didn't start. Check: docker logs d12-game"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker exec d12-game ps"
