#!/usr/bin/env bash
# K12 fix: one changed env var (REDIS_HOST) is a Pod template change, so the Deployment rolls out a new Pod.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

APP="k-12-dns-app"

need_cluster
say "Pointing the app at Redis by its full name…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Waiting for the new Pod to roll out…"
kubectl rollout status deployment/showdown -n "$APP" --timeout=180s >/dev/null \
  || die "The app didn't roll out. Check: kubectl get pods -n $APP"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $APP" \
  "kubectl port-forward -n $APP svc/showdown 9212:80   (in a second terminal; then open http://localhost:9212; on a playground add --address 0.0.0.0 and open the URL for port 9212)"
