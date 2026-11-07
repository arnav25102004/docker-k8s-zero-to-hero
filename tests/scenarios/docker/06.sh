#!/usr/bin/env bash
# Spec for scenario D06 (06-jupyter-oom-killed). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer 2>/dev/null)" "true 137" "d06-trainer was OOM-killed (exit 137)"
}

fixed() {
  assert_eq "$(docker inspect -f '{{.State.ExitCode}}' d06-trainer 2>/dev/null)" "0" "exit code is 0"
  assert_contains "$(docker logs d06-trainer 2>&1)" "model trained" "logs say 'model trained'"
}
