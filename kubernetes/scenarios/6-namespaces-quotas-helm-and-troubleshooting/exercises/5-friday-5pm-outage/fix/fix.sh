#!/usr/bin/env bash
# S6.x5 fix: applies the three fixes one at a time, in the README's order, waiting for each.
# Idempotent: any fix already made by hand is simply applied again (no change), so it is
# safe to run after fixing one, two or all three tracks yourself.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-30-friday"

# Old app Pods are removed shortly after the new ones are Ready: wait until only 2 are left.
two_pods() { [ "$(kubectl get pods -n "$NS" -l app=showdown --no-headers 2>/dev/null | wc -l | tr -d ' ')" = "2" ]; }

need_cluster

say "Fix 1 of 3 (Track A): Redis image tag redis:7.4.12-alpine…"
kubectl apply -f "$HERE/redis.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
kubectl rollout status deployment/redis -n "$NS" --timeout=180s >/dev/null \
  || die "Redis didn't roll out. Check: kubectl get pods -n $NS"

say "Fix 2 of 3 (Track B): Service showdown targetPort 8080…"
kubectl apply -f "$HERE/service.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Fix 3 of 3 (Track C): REDIS_HOST=redis for the app, new Pods roll out…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
# If REDIS_HOST was set by hand long before Redis was fixed, the stalled rollout may have
# passed its progress deadline; it resumes on its own now, so give rollout status a retry.
kubectl rollout status deployment/showdown -n "$NS" --timeout=180s >/dev/null 2>&1 || {
  sleep 5
  kubectl rollout status deployment/showdown -n "$NS" --timeout=120s >/dev/null
} || die "The app didn't roll out. Check: kubectl get pods -n $NS"
wait_for "the old app Pods to be removed" 60 two_pods \
  || die "Old app Pods are still there. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl logs visitor -n $NS --tail=3" \
  "kubectl port-forward -n $NS svc/showdown 9230:80   (in a second terminal; then open http://localhost:9230; on a playground add --address 0.0.0.0 and open the URL for port 9230)"
