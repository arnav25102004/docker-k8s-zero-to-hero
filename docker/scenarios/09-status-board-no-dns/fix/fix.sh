#!/usr/bin/env bash
# D09 fix: create a user-defined network and connect the three running containers to it (no restarts).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

board_says_up() {
  local logs
  logs="$(docker logs --tail 2 d09-board 2>&1)"
  case "$logs" in *"✅ d09-draw up"*"✅ d09-tools up"*) return 0 ;; esac
  return 1
}

need_docker
say "Creating the network d09-net and connecting all three containers to it"
docker network create --label z2h.scenario=d09 d09-net >/dev/null || die "Could not create the network d09-net."
docker network connect d09-net d09-draw || die "Could not connect d09-draw. Did you run break.sh first?"
docker network connect d09-net d09-tools || die "Could not connect d09-tools."
docker network connect d09-net d09-board || die "Could not connect d09-board."

wait_for "the board to turn green (it checks every 3 seconds)" 20 board_says_up \
  || die "The board is still red. Check: docker logs --tail 5 d09-board"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker logs --tail 2 d09-board"
