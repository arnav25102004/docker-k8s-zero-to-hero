#!/usr/bin/env bash
# D09 break: Excalidraw, IT-Tools and a status board all run on the default bridge network, where names don't resolve.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

DRAW_IMAGE="excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9"
TOOLS_IMAGE="corentinth/it-tools:2024.10.22-7ca5933"
PY_IMAGE="python:3.12-alpine"

board_says_down() { docker logs --tail 5 d09-board 2>&1 | grep -q "❌ d09-draw"; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8109 || die "Port 8109 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$DRAW_IMAGE" "about 44 MB"
ensure_image "$TOOLS_IMAGE" "about 24 MB"
ensure_image "$PY_IMAGE" "about 19 MB"

say "Starting Excalidraw and IT-Tools (no network given, so: the default bridge)…"
docker run -d --name d09-draw --label z2h.scenario=d09 "$DRAW_IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"
docker run -d --name d09-tools --label z2h.scenario=d09 "$TOOLS_IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"
say "Starting the campus status board on port 8109…"
docker run -d --name d09-board --label z2h.scenario=d09 -p 8109:8000 \
  -v "$HERE/board.py:/board.py:ro" "$PY_IMAGE" python -u /board.py >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "the status board to report" 30 board_says_down \
  || die "The board didn't start reporting. Run cleanup.sh and try again."

show_next \
  "Open http://localhost:8109: the board shows big red ❌ tiles. The apps are running, though." \
  "docker ps"
