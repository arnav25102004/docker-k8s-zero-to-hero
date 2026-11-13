#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-04-no-endpoints"
need_cluster
if check_rollouts k-04-no-endpoints && check_visitor "$NS"; then
  ok "The Service finds its Pods again, and the visitor sees ✅."
  exit 0
fi
warn "Not yet. Look at the symptom again, make one change, then run ./check.sh once more."
exit 1
