#!/usr/bin/env bash
# S6.1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-38-night-canteen"

rolled_out() { kubectl rollout status deployment/night-canteen -n "$NS" --timeout=2s; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9238 || die "Port 9238 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying the night canteen (the manifest names its own namespace)…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the night canteen to be Ready (the first download can take a minute)" 180 rolled_out \
  || die "The Pods didn't become Ready. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

scene_set
