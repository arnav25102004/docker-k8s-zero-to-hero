#!/usr/bin/env bash
# S3.1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-04-no-endpoints"

rolled_out() { kubectl rollout status deployment/tools -n "$NS" --timeout=2s; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended failure: the Pods are Ready, yet the Service has no addresses.
no_endpoints() { [ -z "$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=tools -o jsonpath='{..addresses}' 2>/dev/null)" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9204 || die "Port 9204 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying IT-Tools (2 Pods), its Service and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the IT-Tools Pods to be Ready (the first download can take a minute)" 180 rolled_out \
  || die "The Pods didn't become Ready. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

no_endpoints || die "Expected a Service with no endpoints, but it has some. Run cleanup.sh and try again."

show_next \
  "Both IT-Tools Pods are Running, but nobody can reach them. The visitor gets no answer. Watch it with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
