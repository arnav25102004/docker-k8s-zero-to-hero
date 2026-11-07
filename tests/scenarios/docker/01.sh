#!/usr/bin/env bash
# Spec for scenario D01 (01-jupyter-vanishes). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(container_state d01-jupyter)" "exited" "d01-jupyter has exited"
  assert_eq "$(docker inspect -f '{{.State.ExitCode}}' d01-jupyter 2>/dev/null)" "127" "exit code is 127"
  assert_contains "$(docker logs d01-jupyter 2>&1)" "not found" "logs say 'not found'"
}

fixed() {
  assert_eq "$(container_state d01-jupyter)" "running" "d01-jupyter is running"
  assert_eq "$(http_code "http://localhost:8101/api/status?token=change-me-123")" "200" "Jupyter answers 200 on :8101"
}
