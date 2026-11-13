#!/usr/bin/env bash
# S1.x2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-18-anti-affinity"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended state: all but one Pod are Running, one is still waiting, and the scheduler wrote an event.
one_waiting() {
  [ "$(kubectl get pods -n "$NS" -l app=whoami --no-headers 2>/dev/null | grep -c ' Pending ')" = "1" ] &&
    [ "$(kubectl get pods -n "$NS" -l app=whoami --no-headers 2>/dev/null | grep -c ' Running ')" = "$((REPLICAS - 1))" ] &&
    kubectl get events -n "$NS" 2>/dev/null | grep -q 'FailedScheduling'
}

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9218 || die "Port 9218 is busy, so this scenario can't start. Free it (see above) and run break.sh again."

die_if_k16_taint

# Replicas = nodes that accept new Pods + 1 (kind: 3 nodes, control-plane tainted -> 2 -> 3 replicas).
# A just-created cluster has nodes that are still starting (they carry a node.kubernetes.io/ taint
# until they are Ready). Wait until none does, then read the count once.
nodes_settled() {
  local t
  t=$(kubectl get nodes -o jsonpath='{range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}' 2>/dev/null) || return 1
  ! printf '%s\n' "$t" | grep -q '^node\.kubernetes\.io/' && [ "$(schedulable_node_count 2>/dev/null || echo 0)" -ge 1 ]
}
wait_for "the nodes to be ready" 60 nodes_settled
if ! NODES=$(schedulable_node_count) || [ "$NODES" -lt 1 ]; then
  warn "Node status right now:"
  kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints[*].key,UNSCHEDULABLE:.spec.unschedulable 2>&1 || true
  die "No node accepts new Pods right now (all tainted or cordoned, or the cluster did not answer). Check: kubectl get nodes. If you just ran K16, run its cleanup.sh first."
fi
REPLICAS=$((NODES + 1))

fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Scaling whoami for the open-house traffic ($REPLICAS Pods)…"
kubectl create configmap visitor-config -n "$NS" --from-literal=want="$REPLICAS" >/dev/null || die "Could not create the visitor settings."
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
kubectl scale deployment/whoami -n "$NS" --replicas="$REPLICAS" >/dev/null || die "Could not scale whoami."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."
wait_for "whoami to finish scaling" 180 one_waiting \
  || die "The Pods never settled as expected. Run cleanup.sh and try again."

show_next \
  "whoami is scaled out to $REPLICAS Pods for the open house, and the site still answers. But is every Pod pulling its weight? Watch the visitor: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
