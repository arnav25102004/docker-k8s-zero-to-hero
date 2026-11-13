#!/usr/bin/env bash
# S6.5 fix: the same Deployment, now with an explicit resources section (requests 64Mi, limits 128Mi).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-20-limitrange"

# The old crash-looping Pods are removed shortly after the new ones are Ready: wait until only the 2 new ones are left.
two_pods() { [ "$(kubectl get pods -n "$NS" -l app=showdown --no-headers 2>/dev/null | wc -l | tr -d ' ')" = "2" ]; }

need_cluster
say "Giving the app its own memory request (64Mi) and limit (128Mi)…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

kubectl rollout status deployment/showdown -n "$NS" --timeout=180s \
  || die "The app didn't become Ready. Check: kubectl get pods -n $NS"

wait_for "the old crashing Pods to be removed" 60 two_pods \
  || die "Extra Pods are still there. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/showdown 9220:80   (in a second terminal; then open http://localhost:9220; on a playground add --address 0.0.0.0 and open the URL for port 9220)"
