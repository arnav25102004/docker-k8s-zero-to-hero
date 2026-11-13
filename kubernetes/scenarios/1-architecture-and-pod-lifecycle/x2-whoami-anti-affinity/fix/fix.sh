#!/usr/bin/env bash
# S1.x2 fix: "never two on the same node" becomes "spread out if you can" (preferred anti-affinity).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-18-anti-affinity"

rolled_out() { kubectl rollout status deployment/whoami -n "$NS" --timeout=2s; }

need_cluster
say "Turning the hard rule into a preference…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "whoami to be rolled out" 180 rolled_out \
  || die "whoami didn't become Ready. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS -o wide" \
  "kubectl port-forward -n $NS svc/whoami 9218:80   (second terminal; then curl localhost:9218)"
