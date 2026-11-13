#!/usr/bin/env bash
# S3.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-05-wrong-port"

rolled_out() { kubectl rollout status deployment/draw -n "$NS" --timeout=2s; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended failure: the Service has addresses, but nothing listens on the port it forwards to.
has_endpoints() { [ -n "$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=draw -o jsonpath='{..addresses}' 2>/dev/null)" ]; }
visitor_failing() { kubectl logs visitor -n "$NS" --tail=3 2>/dev/null | grep -q "❌"; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9205 || die "Port 9205 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying Excalidraw (2 Pods), its Service and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the Excalidraw Pods to be Ready (the first download can take a minute)" 180 rolled_out \
  || die "The Pods didn't become Ready. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

has_endpoints || die "Expected the Service to have endpoints, but it has none. Run cleanup.sh and try again."

wait_for "the visitor to report a failure" 60 visitor_failing \
  || die "The visitor never reported a failure. Run cleanup.sh and try again."

show_next \
  "Both Excalidraw Pods are Running and the Service has endpoints, yet every request fails. Watch the visitor with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
