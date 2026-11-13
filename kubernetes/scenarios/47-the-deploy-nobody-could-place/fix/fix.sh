#!/usr/bin/env bash
# K47 fix: the memory request uses the right unit.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-47-capacity"

settled() { check_rollouts "$NS" >/dev/null 2>&1; }

need_cluster
say "Fixing the memory request…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "both checkout Pods to be placed" 180 settled \
  || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n k-47-capacity --tail=3"
