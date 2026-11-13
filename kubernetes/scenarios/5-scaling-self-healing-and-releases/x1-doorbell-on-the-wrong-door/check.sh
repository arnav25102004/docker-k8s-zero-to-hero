#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-34-doorbell"
need_cluster
ready=$(kubectl get deployment dosa -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
ready=${ready:-0}
if [ "$ready" -lt 2 ]; then
  warn "Not yet: $ready of 2 Pods are Ready. Customers can only be sent to Ready Pods."
  exit 1
fi
addrs=$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=dosa -o jsonpath='{..addresses}' 2>/dev/null)
if [ -z "$addrs" ]; then
  warn "Both Pods say Ready, but the Service has no endpoints yet. Give it a moment and run this again."
  exit 1
fi

ok "The dosa counter is open: both Pods are Ready and the Service is sending customers to them."
exit 0
