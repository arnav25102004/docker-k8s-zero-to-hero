#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-28-job"
need_cluster
succeeded=$(kubectl get job leaderboard-reset -n "$NS" -o jsonpath='{.status.succeeded}' 2>/dev/null)
if [ "${succeeded:-0}" -ge 1 ]; then
  above=$(kubectl exec -n "$NS" deploy/redis -- redis-cli ZCOUNT scores 1 +inf 2>/dev/null)
  players=$(kubectl exec -n "$NS" deploy/redis -- redis-cli ZCARD scores 2>/dev/null)
  if [ "$above" = "0" ] && [ "$players" = "5" ]; then
    ok "The reset Job completed: every score is 0 and all five players are still on the board."
    exit 0
  fi
  warn "The Job completed, but the board is not right (scores above 0: ${above:-?}, players: ${players:-?})."
  exit 1
fi
warn "Not yet: the Job has not completed. Check: kubectl get job,pods -n $NS"
exit 1
