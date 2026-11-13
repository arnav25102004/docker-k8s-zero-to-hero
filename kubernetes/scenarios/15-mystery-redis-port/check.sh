#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-15-mystery-env"
need_cluster
check_rollouts "$NS" || { warn "Not yet. Look at the symptom again, make one change, then run ./check.sh once more."; exit 1; }
if kubectl logs -n "$NS" -l app=score-worker 2>/dev/null | grep -q "worker connected to redis:6379"; then
  ok "The worker connects to redis:6379."
  exit 0
fi
warn "The worker is running but has not connected to redis:6379. Check: kubectl logs -n $NS -l app=score-worker"
exit 1
