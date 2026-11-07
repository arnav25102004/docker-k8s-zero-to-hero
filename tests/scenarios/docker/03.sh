#!/usr/bin/env bash
# Spec for scenario D03 (03-votes-cant-reach-redis). Sourced by tests/scenarios/docker.sh.

broken() {
  local ready vote
  ready="$(curl -s --max-time 5 localhost:8103/readyz)"
  vote="$(curl -s --max-time 5 "localhost:8103/api/vote?option=cats")"
  assert_eq "$(container_state d03-api)" "running" "d03-api is running"
  assert_eq "$(container_state d03-redis)" "running" "d03-redis is running"
  assert_cmd_fails "readyz does not say ready" test "$(printf '%s' "$ready" | grep -c '"ready"')" -gt 0
  assert_contains "$ready" "not ready" "readyz says not ready"
  assert_contains "$vote" "error" "voting reports an error"
}

fixed() {
  local before after
  assert_eq "$(http_code localhost:8103/readyz)" "200" "readyz answers 200"
  curl -s --max-time 5 "localhost:8103/api/vote?option=cats" >/dev/null
  before="$(curl -s --max-time 5 localhost:8103/api/results | grep -o '"cats": *[0-9]*')"
  curl -s --max-time 5 "localhost:8103/api/vote?option=cats" >/dev/null
  after="$(curl -s --max-time 5 localhost:8103/api/results | grep -o '"cats": *[0-9]*')"
  assert_eq "$before" '"cats": 1' "first vote counted"
  assert_eq "$after" '"cats": 2' "second vote increments the count"
}
