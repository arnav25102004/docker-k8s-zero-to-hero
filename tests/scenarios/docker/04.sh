#!/usr/bin/env bash
# Spec for scenario D04 (04-vscode-wrong-password). Sourced by tests/scenarios/docker.sh.

login_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 10 --data-urlencode password=change-me-123 localhost:8104/login; }

broken() {
  assert_eq "$(container_state d04-vscode)" "running" "d04-vscode is running"
  assert_cmd_fails "d04-vscode has no PASSWORD env var" docker exec d04-vscode printenv PASSWORD
  assert_cmd_fails "login with change-me-123 is not accepted (not 302)" test "$(login_code)" = "302"
}

fixed() {
  assert_eq "$(container_state d04-vscode)" "running" "d04-vscode is running"
  assert_eq "$(docker exec d04-vscode printenv PASSWORD)" "change-me-123" "PASSWORD is set inside the container"
  assert_eq "$(login_code)" "302" "login with change-me-123 redirects (302)"
}
