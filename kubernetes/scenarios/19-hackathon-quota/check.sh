#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-19-hackathon"
need_cluster
if check_rollouts k-19-hackathon && check_visitor "$NS"; then
  ok "Both dashboard Pods were admitted and are Ready, and the visitor sees ✅."
  exit 0
fi
warn "Not yet. Look at the symptom again, make one change, then run ./check.sh once more."
exit 1
