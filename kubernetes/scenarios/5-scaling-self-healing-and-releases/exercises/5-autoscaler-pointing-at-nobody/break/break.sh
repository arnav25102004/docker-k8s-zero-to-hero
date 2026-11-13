#!/usr/bin/env bash
# S5.x5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-41-hpa-target"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
rolled_out() { kubectl rollout status deployment/lassi -n "$NS" --timeout=2s; }
hpa_complains() { [ "$(kubectl get hpa lassi -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="AbleToScale")].status}' 2>/dev/null)" = "False" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9241 || die "Port 9241 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Setting the scene…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the stall to be Ready (the first download can take a minute)" 180 rolled_out \
  || die "The Pod didn't become Ready. Run cleanup.sh and try again."
wait_for "the autoscaler to report a problem (it syncs every 15 s)" 120 hpa_complains \
  || die "The autoscaler did not report a problem. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The lassi stall serves happily, but the autoscaler shows <unknown>. Watch it with: kubectl get hpa -n k-41-hpa-target -w (Ctrl+C to stop)." \
  "kubectl get hpa,deployment -n k-41-hpa-target"
