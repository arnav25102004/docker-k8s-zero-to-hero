#!/usr/bin/env bash
# S5.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-07-slow-start"

# The kubelet kills the container on the first failed liveness check, over and over.
# We wait for two restarts and for the app's "slow startup" log line to exist.
restarts() { kubectl get pod -n "$NS" -l app=showdown -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null; }
killed_twice() {
  local n
  n="$(restarts)"
  [ "${n:-0}" -ge 2 ] 2>/dev/null || return 1
  kubectl logs -n "$NS" -l app=showdown --previous 2>&1 | grep -q "simulating slow startup"
}

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9207 || die "Port 9207 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
create_showdown_configmap "$NS" || die "Could not create the ConfigMap showdown-code."

say "Deploying the Cats vs Dogs app and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the app to be killed and restarted twice" 180 killed_twice \
  || die "Expected repeated restarts, but didn't see them. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The app was deployed, but it never becomes ready: the Pod keeps restarting and nobody can vote. Watch it with: kubectl get pods -n $NS -w (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
