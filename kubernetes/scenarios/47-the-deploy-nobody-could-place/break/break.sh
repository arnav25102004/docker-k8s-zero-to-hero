#!/usr/bin/env bash
# K47 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-47-capacity"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
scene_ready() { [ "$(kubectl get pods -n "$NS" -l app=checkout --no-headers 2>/dev/null | grep -c Pending)" -ge 2 ]; }

need_cluster
need_monitoring
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Setting the scene…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "both checkout Pods to be refused a node" 240 scene_ready \
  || die "The Pods did not go Pending as expected. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The checkout service is set up and the visitor is knocking. Watch it with: kubectl logs -f visitor -n k-47-capacity (Ctrl+C to stop). The Prometheus alert page: http://localhost:9090/alerts (kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090)." \
  "kubectl get pods -n k-47-capacity"
