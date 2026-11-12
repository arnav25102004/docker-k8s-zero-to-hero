#!/usr/bin/env bash
# K32 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-32-wrong-object"

rolled_out() { kubectl rollout status deployment/samosa -n "$NS" --timeout=2s; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }


need_cluster
bash "$HERE/../cleanup.sh"
port_free 9232 || die "Port 9232 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Opening the stall(s) and sending in a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the stall(s) to be Ready (the first download can take a minute)" 180 rolled_out \
  || die "The Pods didn't become Ready. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

no_endpoints() { [ -z "$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=samosa -o jsonpath='{..addresses}' 2>/dev/null)" ]; }
no_endpoints || die "Expected a Service with no endpoints, but it has some. Run cleanup.sh and try again."

show_next \
  "The samosa stall is open and both fryers are Running, yet nobody gets a samosa. Watch it with: kubectl logs -f visitor -n k-32-wrong-object (Ctrl+C to stop)." \
  "kubectl get deployment,pods -n k-32-wrong-object --show-labels"
