#!/usr/bin/env bash
# Spec for scenario D07 (07-jupyter-cant-save). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(container_state d07-jupyter)" "running" "d07-jupyter is running"
  assert_cmd_fails "saving into work/assignments fails (Permission denied)" docker exec d07-jupyter touch /home/jovyan/work/assignments/test.ipynb
}

fixed() {
  assert_eq "$(container_state d07-jupyter)" "running" "d07-jupyter is running"
  docker exec d07-jupyter touch /home/jovyan/work/assignments/test.ipynb
  assert_eq "$?" "0" "saving into work/assignments works"
}
