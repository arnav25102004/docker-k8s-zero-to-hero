#!/usr/bin/env bash
# K11 fix: roll back to the previous revision (the good v1).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-11-bad-rollout"

need_cluster
say "Rolling back (kubectl rollout undo)…"
# kubectl prints a long (harmless) warning about "kubectl apply" here; keep it for errors only.
out=$(kubectl rollout undo deployment/showdown -n "$NS" 2>&1) \
  || die "rollout undo failed: $out"

kubectl rollout status deployment/showdown -n "$NS" --timeout=180s \
  || die "The rollback didn't finish. Check: kubectl get pods -n $NS"

# The crashing Pod is removed as part of the rollback; make sure only the 3 good Pods remain.
three_pods() { [ "$(kubectl get pods -n "$NS" -l app=showdown --no-headers 2>/dev/null | wc -l | tr -d ' ')" = "3" ]; }
wait_for "only the 3 good Pods to remain" 60 three_pods \
  || die "Extra Pods are still there. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl rollout history deployment/showdown -n $NS" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/showdown 9211:80   (in a second terminal; then open http://localhost:9211; on a playground add --address 0.0.0.0 and open the URL for port 9211)"
