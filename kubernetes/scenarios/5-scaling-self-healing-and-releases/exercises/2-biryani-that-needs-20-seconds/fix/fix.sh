#!/usr/bin/env bash
# S5.x2 fix: a startupProbe gives the biryani up to 60 s to be ready; liveness only starts after it passes.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-35-slow-biryani"

need_cluster
say "Adding a startup probe so the biryani gets time to cook…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

rolled_out() { kubectl rollout status deployment/biryani -n "$NS" --timeout=2s; }
wait_for "the new Pods to become Ready" 180 rolled_out \
  || die "The rollout did not finish. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n $NS --tail=3"
