#!/usr/bin/env bash
# D07 fix: copy fix/ into work/, hand the volume to uid 1000 / gid 100 (jovyan),
# then apply the fixed compose.yaml. Every Docker command is printed.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"
refuse_if_in_work "$HERE"

# can_save: save a test file through Jupyter (what the Save button does), then delete it again.
can_save() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 -X PUT \
    -H 'Authorization: token change-me-123' -H 'Content-Type: application/json' \
    -d '{"type":"file","format":"text","content":"hello"}' \
    http://localhost:8107/api/contents/work/assignments/fix-check.txt)"
  [ "$code" = "201" ] || return 1
  curl -s -o /dev/null --max-time 3 -X DELETE -H 'Authorization: token change-me-123' \
    http://localhost:8107/api/contents/work/assignments/fix-check.txt
  return 0
}

need_docker
docker volume inspect d07_notebooks >/dev/null 2>&1 \
  || die "The volume d07_notebooks isn't there. Run ./break/break.sh first."

prepare_work "$HERE"
cd "$HERE/.." || die "Could not enter the scenario folder."

say "Step 1: give the files in the volume to uid 1000 / gid 100 (jovyan), using a one-off root container"
run_shown docker compose -f work/compose.yaml run --rm --user root backup chown -R 1000:100 /data \
  || die "The chown container failed. Is Docker healthy?"

say "Step 2: apply the fixed compose.yaml (the backup job now runs as 1000:100)"
run_shown docker compose -f work/compose.yaml up -d \
  || die "docker compose up failed. Try it yourself:  docker compose -f work/compose.yaml up"

wait_for "saving to work to succeed" 30 can_save \
  || die "Saving still fails. Check: docker compose -f work/compose.yaml exec jupyter ls -ln work"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker compose -f work/compose.yaml exec jupyter ls -ln work/assignments"
