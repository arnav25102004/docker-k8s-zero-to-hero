#!/usr/bin/env bash
# S4.x3 fix: the Pod carries all four things the restricted level asks for.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-44-checklist"

settled() { [ "$(kubectl get deployment cart -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "2" ]; }

need_cluster
say "Filling in the restricted checklist…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the cart to open" 180 settled \
  || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n k-44-checklist --tail=3"
