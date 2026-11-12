#!/usr/bin/env bash
# K34 fix: the readiness probe now rings the door the app really has (5678).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-34-doorbell"

need_cluster
say "Pointing the readiness probe at the right port…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

rolled_out() { kubectl rollout status deployment/dosa -n "$NS" --timeout=2s; }
wait_for "the new Pods to become Ready" 180 rolled_out \
  || die "The rollout did not finish. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n $NS --tail=3"
