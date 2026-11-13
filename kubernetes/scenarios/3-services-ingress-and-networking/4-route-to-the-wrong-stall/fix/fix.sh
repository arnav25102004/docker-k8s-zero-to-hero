#!/usr/bin/env bash
# S3.4 fix: the /dosa route points at the Service that really exists.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-33-gateway"

resolved() { [ "$(kubectl get httproute menu -n "$NS" -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)" = "True" ]; }

need_cluster
say "Correcting the name of the dosa Service in the route…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
wait_for "the route to resolve" 120 resolved || die "The route still does not resolve. Check: kubectl describe httproute menu -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n $NS --tail=3"
