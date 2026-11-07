#!/usr/bin/env bash
# Spec for scenario D09 (09-status-board-no-dns). Sourced by tests/scenarios/docker.sh.

broken() {
  local logs
  logs="$(docker logs --tail 5 d09-board 2>&1)"
  assert_eq "$(container_state d09-board)" "running" "d09-board is running"
  assert_eq "$(container_state d09-draw)" "running" "d09-draw is running"
  assert_eq "$(container_state d09-tools)" "running" "d09-tools is running"
  assert_contains "$logs" "❌ d09-draw" "board log says ❌ d09-draw"
}

fixed() {
  local logs i=0
  # The board checks every 3 s: allow up to 10 s for the next two lines.
  while [ "$i" -lt 10 ]; do
    logs="$(docker logs --tail 2 d09-board 2>&1)"
    case "$logs" in *"✅ d09-draw up"*"✅ d09-tools up"*) break ;; esac
    sleep 1
    i=$((i + 1))
  done
  assert_contains "$logs" "✅ d09-draw up" "board log says ✅ d09-draw up"
  assert_contains "$logs" "✅ d09-tools up" "board log says ✅ d09-tools up"
  assert_contains "$(curl -s --max-time 5 localhost:8109)" "d09-draw" "board page answers on :8109"
}
