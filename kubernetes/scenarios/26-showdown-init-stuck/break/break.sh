#!/usr/bin/env bash
# K26 break: deploys Redis and the Cats vs Dogs app, and waits for the app Pod to settle.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-26-init-stuck"

redis_ready() { [ "$(kubectl get pod -n "$NS" -l app=redis -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)" = "true" ]; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# Settled = the app Pod is Pending (never became Ready) and has been busy for a few seconds.
# (Reads the Pod's own start state; no log lines are matched here.)
settled() {
  [ "$(kubectl get pod -n "$NS" -l app=showdown -o jsonpath='{.items[0].status.phase}' 2>/dev/null)" = "Pending" ] || return 1
  [ "$(kubectl get pod -n "$NS" -l app=showdown -o jsonpath='{.items[0].status.initContainerStatuses[0].state.running.startedAt}' 2>/dev/null)" != "" ] || return 1
  kubectl logs -n "$NS" -l app=showdown -c wait-for-redis 2>/dev/null | grep -q .
}

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9226 || die "Port 9226 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
create_showdown_configmap "$NS" || die "Could not create the ConfigMap showdown-code."

say "Deploying Redis, the Cats vs Dogs app and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "Redis to start (the first download can take a minute)" 180 redis_ready \
  || die "Redis didn't start. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."
wait_for "the app Pod to settle" 180 settled \
  || die "The app Pod didn't settle into its failing state. Run cleanup.sh and try again."

show_next \
  "Redis is running, but the app is not coming up and nobody can vote. The visitor sees it live: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
