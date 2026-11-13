#!/usr/bin/env bash
# S3.4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-33-gateway"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
proxy_svc() {
  kubectl get svc -n envoy-gateway-system \
    -l "gateway.envoyproxy.io/owning-gateway-name=stalls,gateway.envoyproxy.io/owning-gateway-namespace=$NS" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}
have_proxy() { [ -n "$(proxy_svc)" ]; }
route_unresolved() {
  [ "$(kubectl get httproute menu -n "$NS" -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)" = "False" ]
}

need_cluster
kubectl get gatewayclass eg >/dev/null 2>&1 || die "No Gateway controller found. This scenario routes traffic through Envoy Gateway. Install it once (about 2 minutes): ./scripts/install-gateway.sh"
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Opening two stalls and a front door (a Gateway) with a route to each…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
wait_for "the Gateway's proxy Service to appear (about a minute)" 240 have_proxy \
  || die "The Gateway's proxy never appeared. Check: kubectl get gateway -n $NS   and   kubectl get pods -n envoy-gateway-system"
wait_for "the route to be evaluated" 120 route_unresolved \
  || die "The route was not evaluated as expected. Run cleanup.sh and try again."

URL="http://$(proxy_svc).envoy-gateway-system.svc.cluster.local"
sed "s#@URL@#$URL#g" "$HERE/visitor.yaml" | kubectl apply -f - >/dev/null || die "Could not start the visitor."
wait_for "the visitor to start" 180 visitor_up || die "The visitor Pod didn't start. Run cleanup.sh and try again."

scene_set
