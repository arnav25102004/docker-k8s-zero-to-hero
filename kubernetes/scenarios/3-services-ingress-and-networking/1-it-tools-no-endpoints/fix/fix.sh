#!/usr/bin/env bash
# S3.1 fix: the Service now selects tier: backend, the label the Pods really carry.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-04-no-endpoints"

rolled_out() { kubectl rollout status deployment/tools -n "$NS" --timeout=2s; }
has_endpoints() { [ -n "$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=tools -o jsonpath='{..addresses}' 2>/dev/null)" ]; }

need_cluster
say "Pointing the Service at the right label (tier: frontend → tier: backend)…"
# A Service's selector can be changed in place, so a plain apply is enough.
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the IT-Tools Deployment to be Ready" 180 rolled_out \
  || die "The Pods didn't become Ready. Check: kubectl get pods -n $NS"

wait_for "the Service to find its Pods" 60 has_endpoints \
  || die "The Service still has no endpoints. Check: kubectl get endpointslices -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get endpointslices -n $NS -l kubernetes.io/service-name=tools" \
  "kubectl port-forward -n $NS svc/tools 9204:80   (in a second terminal; then open http://localhost:9204; on a playground add --address 0.0.0.0 and open the URL for port 9204)"
