#!/usr/bin/env bash
# S5.x5 fix: the autoscaler now points at the Deployment that really exists.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-41-hpa-target"

settled() { [ "$(kubectl get hpa lassi -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="AbleToScale")].status}' 2>/dev/null)" = "True" ]; }

need_cluster
say "Pointing the autoscaler at the right Deployment…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the autoscaler to find its target" 180 settled \
  || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl describe hpa lassi -n k-41-hpa-target"
