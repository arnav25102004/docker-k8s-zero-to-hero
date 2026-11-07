#!/usr/bin/env bash
# D12 break: the shell-form CMD keeps sh as PID 1, so docker stop's SIGTERM never reaches Python and the scores are never saved.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

BASE_IMAGE="python:3.12-alpine"
API="http://localhost:8112/api/scores"

app_answers() { curl -s -o /dev/null --max-time 2 "$API"; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8112 || die "Port 8112 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$BASE_IMAGE" "about 19 MB"

say "Building the game: docker build -t d12-game:1.0 ."
cd "$HERE" || die "Could not enter $HERE"
docker build -q --label z2h.scenario=d12 -t d12-game:1.0 . >/dev/null \
  || die "The build failed. Try: docker build -t d12-game:1.0 ."
docker volume create --label z2h.scenario=d12 d12-data >/dev/null || die "Could not create the volume d12-data."
say "Starting it: docker run -d --name d12-game -p 8112:8000 -v d12-data:/data d12-game:1.0"
docker run -d --name d12-game --label z2h.scenario=d12 -p 8112:8000 -v d12-data:/data d12-game:1.0 >/dev/null \
  || die "docker run failed. Is port 8112 free?"
wait_for "the game server to start" 30 app_answers \
  || die "The server didn't start. Check: docker logs d12-game"

say "Three players beat the high score tonight: Lakshmi 42, Ravi 35, Meera 28"
for entry in Lakshmi:42 Ravi:35 Meera:28; do
  curl -s -o /dev/null -X POST -H 'Content-Type: application/json' \
    -d "{\"name\":\"${entry%%:*}\",\"score\":${entry##*:}}" "$API" \
    || die "Could not post a score. Check: docker logs d12-game"
done

say "Deploy time! Restarting the server: docker stop -t 10 d12-game && docker start d12-game"
docker stop -t 10 d12-game >/dev/null || die "docker stop failed."
docker start d12-game >/dev/null || die "docker start failed."
wait_for "the game server to come back" 30 app_answers \
  || die "The server didn't come back. Check: docker logs d12-game"

show_next \
  "The game is back. Open http://localhost:8112 (playground: the port 8112 URL): Lakshmi, Ravi and Meera were on the board a moment ago. Look at the Top 5." \
  "curl localhost:8112/api/scores"
