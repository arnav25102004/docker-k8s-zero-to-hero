#!/usr/bin/env bash
# Spec for scenario D02 (02-port-clash). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(container_state d02-draw)" "running" "d02-draw is running"
  assert_eq "$(container_state d02-tools)" "created" "d02-tools is stuck in created"
  assert_cmd_fails "nothing answers 200 on :8202" test "$(http_code http://localhost:8202)" = "200"
  assert_eq "$([ -d docker/scenarios/02-port-clash/work ] && echo yes || echo no)" "no" "no work/ folder (nothing to edit in D02)"
}

fixed() {
  assert_eq "$(container_state d02-draw)" "running" "d02-draw is running"
  assert_eq "$(container_state d02-tools)" "running" "d02-tools is running"
  assert_eq "$(http_code http://localhost:8102)" "200" "Excalidraw answers 200 on :8102"
  assert_eq "$(http_code http://localhost:8202)" "200" "IT-Tools answers 200 on :8202"
}
