#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-36-two-probes"
need_cluster
ready=$(kubectl get deployment thali -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
ready=${ready:-0}
if [ "$ready" -lt 2 ]; then
  warn "Not yet: $ready of 2 Pods are Ready. Customers can only be sent to Ready Pods."
  exit 1
fi
addrs=$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=thali -o jsonpath='{..addresses}' 2>/dev/null)
if [ -z "$addrs" ]; then
  warn "Both Pods say Ready, but the Service has no endpoints yet. Give it a moment and run this again."
  exit 1
fi

sum_restarts() { kubectl get pods -n "$NS" -l app=thali -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null | awk '{s+=$1} END{print s+0}'; }
say "Watching the stall for ${Z2H_CHECK_WATCH:-12} seconds to see whether it stays up…"
r1=$(sum_restarts)
sleep "${Z2H_CHECK_WATCH:-12}"
r2=$(sum_restarts)
if [ "$r1" != "$r2" ]; then
  warn "The stall restarted while I was watching ($r1 → $r2 restarts). Not stable yet."
  exit 1
fi

ok "Both probes are honest now: the thali stall is Ready and stays up."
exit 0
