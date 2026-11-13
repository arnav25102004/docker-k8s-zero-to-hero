#!/usr/bin/env bash
# S6.4 fix: the Service now asks for app: chai AND track: fresh, so only the fresh stall matches.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-31-two-stalls"

need_cluster
say "Making the Service selector more precise (app: chai + track: fresh)…"
kubectl apply -f "$HERE/service.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

only_fresh() { ! kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=chai -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}{"\n"}{end}' 2>/dev/null | grep -q '^stale-chai-'; }
wait_for "the Service to stop sending customers to the stale stall" 60 only_fresh \
  || die "The stale stall is still behind the Service. Check: kubectl get endpointslices -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "kubectl logs visitor -n k-31-two-stalls --tail=5   (only fresh chai now)   ·   ./check.sh"
