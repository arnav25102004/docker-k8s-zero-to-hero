#!/usr/bin/env bash
# S6.x1 fix: the memory limit now fits under the namespace maximum.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-40-limit-max"

settled() { [ "$(kubectl get deployment chaat -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "2" ]; }

need_cluster
say "Asking for a memory limit the kitchen allows…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the stall to open" 180 settled \
  || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n k-40-limit-max --tail=3"
