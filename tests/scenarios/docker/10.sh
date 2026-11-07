#!/usr/bin/env bash
# Spec for scenario D10 (10-qr-app-build-fails). Sourced by tests/scenarios/docker.sh.

broken() {
  local rc=0
  # The build must fail again (same command break.sh ran), and no image may exist.
  docker build -q -t d10-qr:1.0 "$REPO/docker/scenarios/10-qr-app-build-fails/break" >/dev/null 2>&1 || rc=$?
  assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "docker build exits non-zero"
  assert_eq "$(docker images -q d10-qr:1.0)" "" "image d10-qr:1.0 does not exist"
}

fixed() {
  assert_eq "$(http_code http://localhost:8110)" "200" "app answers 200 on :8110"
  local js
  js="$(curl -s localhost:8110/qrcode.min.js | head -c 200)"
  assert_contains "$js" "qrcode" "qrcode.min.js is served and non-empty"
}
