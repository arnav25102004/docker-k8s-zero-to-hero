#!/usr/bin/env bash
# Spec for scenario D06 (06-ai-trainer-oom-killed). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer-1 2>/dev/null)" "true 137" "d06-trainer-1 was OOM-killed (exit 137)"
  assert_eq "$(docker inspect -f '{{.HostConfig.Memory}}' d06-trainer-1 2>/dev/null)" "314572800" "memory limit is 300 MiB"
}

fixed() {
  assert_eq "$(docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer-1 2>/dev/null)" "false 0" "not killed, exit code 0"
  assert_contains "$(docker logs d06-trainer-1 2>&1)" "model trained" "logs say 'model trained'"
}
