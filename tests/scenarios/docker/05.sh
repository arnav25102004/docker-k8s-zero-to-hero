#!/usr/bin/env bash
# Spec for scenario D05 (05-image-tag-typo). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(docker ps -aq --filter name=^d05-tools$)" "" "no container named d05-tools exists"
  assert_eq "$(docker image ls -q d05-tools:1.0)" "" "image d05-tools:1.0 was not built"
  assert_contains "$(cat "$(dirname "${BASH_SOURCE[0]}")/../../../docker/scenarios/05-image-tag-typo/work/Dockerfile")" "7ca5393" "work/Dockerfile holds the mistyped tag"
}

fixed() {
  assert_eq "$(container_state d05-tools)" "running" "d05-tools is running"
  assert_eq "$(http_code http://localhost:8105)" "200" "IT-Tools answers 200 on port 8105"
  assert_contains "$(curl -s --max-time 5 http://localhost:8105/hello.html)" "Campus IT-Tools is live" "hello.html (COPY'd into the image) is served"
  assert_eq "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.title"}}' d05-tools:1.0)" "Campus IT-Tools" "image carries its title label"
}
