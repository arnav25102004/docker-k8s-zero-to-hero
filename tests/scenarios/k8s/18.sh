#!/usr/bin/env bash
# Spec for scenario K18 (18-whoami-anti-affinity). Sourced by tests/scenarios/k8s.sh.
# Works on 1-node and 3-node clusters: replicas = schedulable nodes + 1.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-18-anti-affinity"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  local i want pending running events
  want=$(( $(schedulable_node_count) + 1 ))
  for i in $(seq 1 30); do
    pending=$(kubectl get pods -n k-18-anti-affinity -l app=whoami --no-headers 2>/dev/null | grep -c ' Pending ')
    [ "$pending" = "1" ] && break
    sleep 2
  done
  running=$(kubectl get pods -n k-18-anti-affinity -l app=whoami --no-headers 2>/dev/null | grep -c ' Running ')
  assert_eq "$(kubectl get deployment whoami -n k-18-anti-affinity -o jsonpath='{.spec.replicas}' 2>&1)" "$want" "replicas = schedulable nodes + 1"
  assert_eq "$pending" "1" "exactly 1 whoami Pod is Pending"
  assert_eq "$running" "$((want - 1))" "all the other whoami Pods are Running"
  events="$(kubectl get events -n k-18-anti-affinity 2>&1)"
  assert_contains "$events" "didn't match pod anti-affinity rules" "events say the Pod didn't match pod anti-affinity rules"
}

fixed() {
  local want
  want=$(( $(schedulable_node_count) + 1 ))
  kubectl rollout status deployment/whoami -n k-18-anti-affinity --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "whoami Deployment rolled out"
  assert_eq "$(kubectl get deployment whoami -n k-18-anti-affinity -o jsonpath='{.status.readyReplicas}' 2>&1)" "$want" "all $want replicas are Ready"
  assert_eq "$(in_cluster_http k-18-anti-affinity http://whoami)" "200" "whoami answers 200 inside the cluster"
}
