#!/usr/bin/env bash
# Spec for scenario D05 (05-image-tag-typo). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(docker ps -aq --filter name=^d05-tools$)" "" "no container named d05-tools exists"
}

fixed() {
  assert_eq "$(container_state d05-tools)" "running" "d05-tools is running"
  assert_eq "$(http_code http://localhost:8105)" "200" "IT-Tools answers 200 on port 8105"
}
