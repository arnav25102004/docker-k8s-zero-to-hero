#!/usr/bin/env bash
# K46 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-46-3am"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
scene_ready() { [ "$(kubectl get pods -n "$NS" -l app=orders -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo 0)" -ge 2 ] 2>/dev/null; }

need_cluster
need_monitoring
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Setting the scene…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the orders Pod to crash a couple of times" 240 scene_ready \
  || die "The orders Pod did not crash as expected. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The orders service is set up and the visitor is knocking. Watch it with: kubectl logs -f visitor -n k-46-3am (Ctrl+C to stop). In about two minutes the alert fires: http://localhost:9090/alerts (kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090)." \
  "kubectl get pods -n k-46-3am"
