#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-37-stuck-pod"
need_cluster
if kubectl get pod old-stall -n "$NS" >/dev/null 2>&1; then
  since=$(kubectl get pod old-stall -n "$NS" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null)
  if [ -n "$since" ]; then
    warn "Not yet: old-stall has been 'being deleted' since $since, and it is still here."
  else
    warn "Not yet: old-stall is still here (and nobody has asked for it to be deleted)."
  fi
  exit 1
fi
ok "The old stall is finally gone. Closing time, for real this time."
exit 0
