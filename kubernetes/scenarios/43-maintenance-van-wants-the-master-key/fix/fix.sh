#!/usr/bin/env bash
# K43 fix: the container no longer asks to be privileged.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-43-van"

settled() { [ "$(kubectl get deployment van -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "2" ]; }

need_cluster
say "Taking the master key away from the van…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the van to open" 180 settled \
  || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n k-43-van --tail=3"
