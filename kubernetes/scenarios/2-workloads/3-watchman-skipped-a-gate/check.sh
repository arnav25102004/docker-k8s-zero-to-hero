#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-16-daemonset"
need_cluster
nodes=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
want=$(kubectl get daemonset watchman -n "$NS" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
ready=$(kubectl get daemonset watchman -n "$NS" -o jsonpath='{.status.numberReady}' 2>/dev/null)
if [ "${want:-0}" = "$nodes" ] && [ "${ready:-0}" = "$nodes" ]; then
  ok "A watchman at every gate: $ready of $nodes nodes covered."
  exit 0
fi
warn "Not yet: the DaemonSet wants ${want:-0} watchmen (ready: ${ready:-0}) but the cluster has $nodes nodes."
exit 1
