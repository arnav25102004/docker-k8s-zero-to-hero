#!/usr/bin/env bash
# D09 fix: put the fixed files in work/, then let Compose recreate the services. Every Docker command is printed first.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"
refuse_if_in_work "$HERE"

board_says_up() {
  local logs
  logs="$(docker logs --tail 2 d09-board-1 2>&1)"
  case "$logs" in *"✅ draw up"*"✅ tools up"*) return 0 ;; esac
  return 1
}

need_docker
prepare_work "$HERE"
cd "$HERE/.." || die "Could not enter the scenario folder"

run_shown docker compose -f work/compose.yaml up -d \
  || die "docker compose up failed. Read the message above, then try again."

wait_for "the board to turn green (it checks every 3 seconds)" 30 board_says_up \
  || die "The board is still red. Check: docker compose -f work/compose.yaml logs --tail 5 board"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker compose -f work/compose.yaml logs --tail 2 board"
