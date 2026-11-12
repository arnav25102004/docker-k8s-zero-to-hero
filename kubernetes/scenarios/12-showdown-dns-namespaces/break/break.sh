#!/usr/bin/env bash
# K12 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

APP="k-12-dns-app"
DATA="k-12-dns-data"

redis_ready() { [ "$(kubectl get pod -n "$DATA" -l app=redis -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)" = "true" ]; }
# The intended failure: the app is up and running, but cannot find Redis (readiness answers 503).
app_cannot_find_redis() {
  kubectl get pod -n "$APP" -l app=showdown -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running || return 1
  kubectl logs -n "$APP" -l app=showdown 2>&1 | grep -q "listening on" || return 1
  kubectl logs -n "$APP" visitor 2>/dev/null | grep -q "not ready"
}
visitor_up() { [ "$(kubectl get pod visitor -n "$APP" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9212 || die "Port 9212 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$APP" "$DATA" || die "Could not create the namespaces $APP and $DATA."
create_showdown_configmap "$APP" || die "Could not create the ConfigMap showdown-code."

say "Deploying Redis (in $DATA), the Cats vs Dogs app and a visitor (in $APP)…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "Redis to start (the first download can take a minute)" 180 redis_ready \
  || die "Redis didn't start. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."
wait_for "the app to start and fail to find Redis" 180 app_cannot_find_redis \
  || die "Expected the app to be up but not ready, and it isn't. Run cleanup.sh and try again."

show_next \
  "Redis is running. The app is running too. But the app says it is not ready and nobody can vote. The visitor sees it live: kubectl logs -f visitor -n $APP (Ctrl+C to stop)." \
  "kubectl get pods -n $APP"
