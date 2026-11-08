#!/usr/bin/env bash
# K05 fix: the Service now forwards to targetPort 80, the port Excalidraw really listens on.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-05-wrong-port"

rolled_out() { kubectl rollout status deployment/draw -n "$NS" --timeout=2s; }
has_endpoints() { [ -n "$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=draw -o jsonpath='{..addresses}' 2>/dev/null)" ]; }

need_cluster
say "Pointing the Service at the right container port (targetPort 8080 → 80)…"
# A Service's targetPort can be changed in place, so a plain apply is enough.
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the Excalidraw Deployment to be Ready" 180 rolled_out \
  || die "The Pods didn't become Ready. Check: kubectl get pods -n $NS"

wait_for "the Service to have endpoints" 60 has_endpoints \
  || die "The Service has no endpoints. Check: kubectl get endpointslices -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get endpointslices -n $NS -l kubernetes.io/service-name=draw" \
  "kubectl port-forward -n $NS --address 0.0.0.0 svc/draw 9205:80   (in a second terminal; then open http://localhost:9205)"
