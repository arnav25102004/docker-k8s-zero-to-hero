#!/usr/bin/env bash
# S2.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-15-statefulset"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
first_up() { [ "$(kubectl get pod stall-0 -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Setting the scene…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the first stall (stall-0) to start (the first download can take a minute)" 180 first_up \
  || die "stall-0 did not start. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "Three stalls were ordered. Look at what exists. The visitor is waiting: kubectl logs -f visitor -n k-15-statefulset (Ctrl+C to stop)." \
  "kubectl get statefulset,pods -n k-15-statefulset"
