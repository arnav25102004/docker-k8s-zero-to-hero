#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-15-statefulset"
need_cluster
ready=$(kubectl get statefulset stall -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
ready=${ready:-0}
if [ "$ready" = "3" ] && check_visitor "$NS"; then
  ok "All three stalls are open (stall-0, stall-1, stall-2) and the visitor sees ✅."
  exit 0
fi
warn "Not yet: $ready of 3 stalls are Ready. A StatefulSet opens its Pods one at a time: it waits for each to be Ready before creating the next."
exit 1
