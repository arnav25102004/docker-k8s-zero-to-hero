#!/usr/bin/env bash
# K33 fix: the Pods wear the right label and the Service knocks on the right port.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-33-canteen"

need_cluster
say "Recreating the Deployment with the right label (a Deployment's selector cannot be edited), and fixing the Service port…"
kubectl delete deployment canteen -n "$NS" --wait=true >/dev/null 2>&1
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
kubectl rollout status deployment/canteen -n "$NS" --timeout=180s >/dev/null 2>&1 || die "The rollout did not finish. Check: kubectl get pods -n $NS"

has_endpoints() { [ -n "$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=canteen -o jsonpath='{..addresses}' 2>/dev/null)" ]; }
wait_for "the Service to find its Pods" 60 has_endpoints \
  || die "The Service still has no endpoints. Check: kubectl get endpointslices -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n k-33-canteen --tail=3"
