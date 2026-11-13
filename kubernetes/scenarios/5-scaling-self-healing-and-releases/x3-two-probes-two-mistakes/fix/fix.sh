#!/usr/bin/env bash
# S5.x3 fix: readiness asks for a page that exists, and liveness rings the port the app really listens on.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-36-two-probes"

need_cluster
say "Correcting both probes…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

rolled_out() { kubectl rollout status deployment/thali -n "$NS" --timeout=2s; }
wait_for "the new Pods to become Ready" 180 rolled_out \
  || die "The rollout did not finish. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n $NS --tail=3"
