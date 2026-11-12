#!/usr/bin/env bash
# K32 fix: the label now sits on the Pod template, where the Service looks.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-32-wrong-object"

need_cluster
say "Moving the label onto the Pod template (Pods get replaced one by one)…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
kubectl rollout status deployment/samosa -n "$NS" --timeout=180s >/dev/null 2>&1 || die "The rollout did not finish. Check: kubectl get pods -n $NS"

has_endpoints() { [ -n "$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=samosa -o jsonpath='{..addresses}' 2>/dev/null)" ]; }
wait_for "the Service to find its Pods" 60 has_endpoints \
  || die "The Service still has no endpoints. Check: kubectl get endpointslices -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n k-32-wrong-object --tail=3"
