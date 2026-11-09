#!/usr/bin/env bash
# Spec for scenario D08 (08-it-tools-unhealthy). Sourced by tests/scenarios/docker.sh.

WORK_DF="$(dirname "${BASH_SOURCE[0]}")/../../../docker/scenarios/08-it-tools-unhealthy/work/Dockerfile"

broken() {
  assert_contains "$(cat "$WORK_DF")" "8080" "work/Dockerfile HEALTHCHECK probes port 8080"
  assert_eq "$(docker inspect -f '{{.State.Health.Status}}' d08-tools 2>/dev/null)" "unhealthy" "d08-tools is reported unhealthy"
  assert_eq "$(http_code http://localhost:8108)" "200" "yet the app answers 200 on :8108"
}

fixed() {
  assert_eq "$(docker inspect -f '{{.Config.Image}}' d08-tools 2>/dev/null)" "d08-tools:1.0" "d08-tools runs the image we built"
  assert_eq "$(docker inspect -f '{{.State.Health.Status}}' d08-tools 2>/dev/null)" "healthy" "d08-tools is reported healthy"
  assert_eq "$(http_code http://localhost:8108)" "200" "the app answers 200 on :8108"
}
