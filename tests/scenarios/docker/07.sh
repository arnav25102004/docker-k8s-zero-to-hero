#!/usr/bin/env bash
# Spec for scenario D07 (07-jupyter-cant-save). Sourced by tests/scenarios/docker.sh.

# save_code: HTTP status of saving a file through Jupyter's contents API (the
# same call the Save button makes). The reply body goes to the file named in $1.
save_code() {
  curl -s -o "$1" -w '%{http_code}' --max-time 5 -X PUT \
    -H 'Authorization: token change-me-123' -H 'Content-Type: application/json' \
    -d '{"type":"file","format":"text","content":"hello"}' \
    http://localhost:8107/api/contents/work/assignments/test.txt
}

broken() {
  assert_eq "$(container_state d07-jupyter-1)" "running" "d07-jupyter-1 is running"
  assert_eq "$(docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' d07-backup-1)" "exited 0" "the backup job exited with 0"
  local code body f
  f="$(mktemp)"
  code="$(save_code "$f")"
  body="$(cat "$f")"; rm -f "$f"
  assert_eq "$code" "403" "saving through Jupyter is refused (HTTP 403)"
  assert_contains "$body" "Permission denied" "the refusal says Permission denied"
  assert_eq "$(docker exec d07-jupyter-1 stat -c %u /home/jovyan/work/assignments)" "0" "assignments is owned by uid 0"
}

fixed() {
  assert_eq "$(container_state d07-jupyter-1)" "running" "d07-jupyter-1 is running"
  assert_eq "$(docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' d07-backup-1)" "exited 0" "the re-run backup job exited with 0"
  assert_eq "$(docker inspect -f '{{.Config.User}}' d07-backup-1)" "1000:100" "backup runs as 1000:100"
  local code f
  f="$(mktemp)"
  code="$(save_code "$f")"; rm -f "$f"
  assert_eq "$code" "201" "saving through Jupyter works (HTTP 201)"
}
