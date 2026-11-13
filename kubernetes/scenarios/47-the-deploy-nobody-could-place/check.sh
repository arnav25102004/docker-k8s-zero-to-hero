#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-47-capacity"
need_cluster
if check_rollouts "$NS" && check_visitor "$NS"; then
  ok "Both checkout Pods are placed and Ready, and the visitor sees ✅."
  exit 0
fi
warn "Not yet. Pods that cannot be placed stay Pending; ask them why."
exit 1
