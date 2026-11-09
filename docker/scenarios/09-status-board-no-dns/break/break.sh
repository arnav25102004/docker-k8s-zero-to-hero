#!/usr/bin/env bash
# D09 break: copy the files to work/, then start the three services with Compose. Every Docker command is printed first.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"
refuse_if_in_work "$HERE"

DRAW_IMAGE="excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9"
TOOLS_IMAGE="corentinth/it-tools:2024.10.22-7ca5933"
PY_IMAGE="python:3.12-alpine"

board_says_down() { docker logs --tail 5 d09-board-1 2>&1 | grep -q "❌ draw"; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8109 || die "Port 8109 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$DRAW_IMAGE" "about 44 MB"
ensure_image "$TOOLS_IMAGE" "about 24 MB"
ensure_image "$PY_IMAGE" "about 19 MB"

prepare_work "$HERE"
cd "$HERE/.." || die "Could not enter the scenario folder"

run_shown docker compose -f work/compose.yaml up -d \
  || die "docker compose up failed. Read the message above, then try again."

wait_for "the status board to report" 30 board_says_down \
  || die "The board didn't start reporting. Run cleanup.sh and try again."

show_next \
  "Open http://localhost:8109 (playground: the port 8109 URL): the board shows big red ❌ tiles. The apps are running, though." \
  "docker compose -f work/compose.yaml ps"
