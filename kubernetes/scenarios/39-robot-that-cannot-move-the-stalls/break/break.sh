#!/usr/bin/env bash
# K39 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-39-idli-robot"

rolled_out() { kubectl rollout status deployment/idli -n "$NS" --timeout=2s; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
budget_ready() { [ "$(kubectl get pdb idli-pdb -n "$NS" -o jsonpath='{.status.currentHealthy}' 2>/dev/null)" = "2" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9239 || die "Port 9239 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Opening the idli stall (two Pods) and a safety rule…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the idli stall to be Ready (the first download can take a minute)" 180 rolled_out \
  || die "The Pods didn't become Ready. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."
wait_for "the safety rule to count both Pods" 60 budget_ready \
  || die "The safety rule did not settle. Run cleanup.sh and try again."

show_next \
  "The idli stall is open and happy. Tonight the maintenance robot needs to move one Pod. Send it in: ./evict.sh" \
  "./evict.sh"
