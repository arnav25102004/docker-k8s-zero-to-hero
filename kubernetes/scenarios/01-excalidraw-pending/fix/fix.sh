#!/usr/bin/env bash
# K01 fix: the same Deployment, with a realistic memory request (64Mi) and a limit (128Mi).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-01-pending"

rolled_out() { kubectl rollout status deployment/draw -n "$NS" --timeout=2s; }

need_cluster
say "Applying the corrected requests (64Mi memory, 50m CPU) and a 128Mi limit…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the whiteboard Pod to be Ready" 120 rolled_out \
  || die "The Pod didn't become Ready. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS --address 0.0.0.0 svc/draw 9201:80   (in a second terminal; then open http://localhost:9201)"
