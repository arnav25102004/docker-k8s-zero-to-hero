#!/usr/bin/env bash
# K48 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-48-ramp"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
scene_ready() { [ "$(kubectl get pods -n "$NS" -l app=cache -o jsonpath='{.items[0].status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
need_monitoring
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Setting the scene…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the cache to start (the first download can take a minute)" 240 scene_ready \
  || die "The cache Pod did not start. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The cache is set up and growing. It takes about a minute to hit its limit, then it dies and starts again. Watch the memory climb in Grafana (Kubernetes / Compute Resources / Pod, namespace k-48-ramp), or: kubectl get pods -n k-48-ramp -w" \
  "kubectl get pods -n k-48-ramp"
