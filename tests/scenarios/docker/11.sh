#!/usr/bin/env bash
# Spec for scenario D11 (11-portfolio-localhost-only). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(container_state d11-portfolio)" "running" "container d11-portfolio is running"
  local code
  code="$(http_code http://localhost:8111)"
  assert_eq "$([ "$code" != "200" ] && echo not-200 || echo 200)" "not-200" "localhost:8111 does not answer 200 (got $code)"
  local inside
  inside="$(docker exec d11-portfolio wget -qO- http://127.0.0.1:8000 2>&1)"
  assert_contains "$inside" "Priya" "the page answers from inside the container"
}

fixed() {
  assert_eq "$(http_code http://localhost:8111)" "200" "portfolio answers 200 on :8111"
}
