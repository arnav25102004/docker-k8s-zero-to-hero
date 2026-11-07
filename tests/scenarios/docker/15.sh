#!/usr/bin/env bash
# Spec for scenario D15 (15-compose-start-order). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(docker compose -p d15 ps -a app --format '{{.State}} {{.ExitCode}}')" "exited 1" "app exited with code 1"
  assert_contains "$(docker compose -p d15 logs app 2>&1)" "database not reachable" "app logged that the database was not reachable"
}

fixed() {
  assert_eq "$(docker compose -p d15 ps -a app --format '{{.State}}')" "running" "app is running"
  assert_eq "$(docker inspect -f '{{.State.Health.Status}}' d15-db-1)" "healthy" "db is healthy"
  assert_eq "$(http_code http://localhost:8115)" "200" "http://localhost:8115 answers 200"
}
