#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-41-hpa-target"
need_cluster
able=$(kubectl get hpa lassi -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="AbleToScale")].status}' 2>/dev/null)
reason=$(kubectl get hpa lassi -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="AbleToScale")].reason}' 2>/dev/null)
if [ "$able" = "True" ]; then
  ok "The autoscaler found its Deployment and can scale it. (Whether it has CPU numbers to act on is a separate question, and a metrics-server's job.)"
  exit 0
fi
warn "Not yet: the autoscaler says it is not able to scale (${reason:-no status yet}). The autoscaler syncs every 15 seconds, so give it a moment after a change."
exit 1
