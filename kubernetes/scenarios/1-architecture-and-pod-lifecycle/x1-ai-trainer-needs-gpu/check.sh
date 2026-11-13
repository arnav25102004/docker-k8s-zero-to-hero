#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-17-needs-gpu"
need_cluster
check_rollouts "$NS" || { warn "Not yet. Look at the symptom again, make one change, then run ./check.sh once more."; exit 1; }
if kubectl logs -n "$NS" -l app=trainer 2>/dev/null | grep -q "model trained"; then
  ok "The trainer finished: the logs say 'model trained'."
  exit 0
fi
warn "The trainer is running but has not finished training yet. Give it a few seconds and run ./check.sh again."
exit 1
