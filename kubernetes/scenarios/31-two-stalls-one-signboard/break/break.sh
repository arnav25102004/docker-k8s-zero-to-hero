#!/usr/bin/env bash
# K31 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-31-two-stalls"

rolled_out() { kubectl rollout status deployment/chai -n "$NS" --timeout=2s && kubectl rollout status deployment/stale-chai -n "$NS" --timeout=2s; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
all_pods_behind_service() { kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=chai -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}{"\n"}{end}' 2>/dev/null | grep -c . | grep -q '^3$'; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9231 || die "Port 9231 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Opening the stall(s) and sending in a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the stall(s) to be Ready (the first download can take a minute)" 180 rolled_out \
  || die "The Pods didn't become Ready. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

wait_for "the Service to pick up all three Pods" 60 all_pods_behind_service \
  || die "The Service did not pick up all three Pods in time. Run cleanup.sh and try again."

show_next \
  "The visitor is getting chai, but not always the same chai. Watch it with: kubectl logs -f visitor -n k-31-two-stalls (Ctrl+C to stop)." \
  "kubectl get pods -n k-31-two-stalls --show-labels"
