#!/usr/bin/env bash
# Spec for scenario D09 (09-status-board-no-dns). Sourced by tests/scenarios/docker.sh.

broken() {
  local logs
  logs="$(docker logs --tail 5 d09-board-1 2>&1)"
  assert_eq "$(container_state d09-board-1)" "running" "d09-board-1 is running"
  assert_eq "$(container_state d09-draw-1)" "running" "d09-draw-1 is running"
  assert_eq "$(container_state d09-tools-1)" "running" "d09-tools-1 is running"
  assert_eq "$(docker inspect -f '{{.HostConfig.NetworkMode}}' d09-board-1)" "bridge" "the board is on the default bridge"
  assert_contains "$logs" "❌ draw" "board log says ❌ draw"
  assert_contains "$(cat docker/scenarios/09-status-board-no-dns/work/compose.yaml 2>&1)" "network_mode: bridge" "work/compose.yaml holds network_mode: bridge"
}

fixed() {
  local logs i=0
  # The board checks every 3 s: allow up to 10 s for the next two lines.
  while [ "$i" -lt 10 ]; do
    logs="$(docker logs --tail 2 d09-board-1 2>&1)"
    case "$logs" in *"✅ draw up"*"✅ tools up"*) break ;; esac
    sleep 1
    i=$((i + 1))
  done
  assert_contains "$logs" "✅ draw up" "board log says ✅ draw up"
  assert_contains "$logs" "✅ tools up" "board log says ✅ tools up"
  assert_eq "$(docker inspect -f '{{.HostConfig.NetworkMode}}' d09-board-1)" "d09_default" "the board is on d09_default"
  assert_contains "$(curl -s --max-time 5 localhost:8109)" "draw" "board page answers on :8109"
}
