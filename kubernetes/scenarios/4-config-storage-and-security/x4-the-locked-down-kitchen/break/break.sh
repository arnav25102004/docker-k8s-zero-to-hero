#!/usr/bin/env bash
# S4.x4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-45-lockdown"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
cfgerr() { kubectl get pods -n "$NS" -l app=kitchen -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null | grep -q CreateContainerConfigError; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9245 || die "Port 9245 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
kubectl label namespace "$NS" pod-security.kubernetes.io/enforce=restricted --overwrite >/dev/null || die "Could not label the namespace."
say "Setting the scene…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the Pods to be admitted and then stuck (the first download can take a minute)" 180 cfgerr \
  || die "The Pods did not get stuck as expected. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The locked-down kitchen is set up, and the visitor is waiting. Watch it with: kubectl logs -f visitor -n k-45-lockdown (Ctrl+C to stop)." \
  "kubectl get deployment,pods -n k-45-lockdown"
