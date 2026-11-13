#!/usr/bin/env bash
# Spec for scenario K39 (39-robot-that-cannot-move-the-stalls). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-39-idli-robot"
SCEN39="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/5-scaling-self-healing-and-releases/x4-robot-that-cannot-move-the-stalls" && pwd)"

allowed39() { kubectl get pdb idli-pdb -n k-39-idli-robot -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null; }

broken() {
  kubectl rollout status deployment/idli -n k-39-idli-robot --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "idli Deployment is Ready"
  assert_eq "$(allowed39)" "0" "the safety rule allows 0 disruptions"
  local out
  out="$(bash "$SCEN39/evict.sh" 2>&1)"
  assert_eq "$?" "1" "the robot is refused (non-zero exit)"
  assert_contains "$out" "disruption budget" "...and the message names the disruption budget"
  assert_cmd_fails "check.sh says: not done yet" bash "$SCEN39/check.sh"
  # The tempting wrong fix: a plain delete bypasses the rule entirely (it only guards evictions).
  local pod
  pod="$(kubectl get pods -n k-39-idli-robot -l app=idli -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  kubectl delete pod "$pod" -n k-39-idli-robot --wait=false >/dev/null 2>&1
  local i
  for i in $(seq 1 15); do
    kubectl get pod "$pod" -n k-39-idli-robot >/dev/null 2>&1 || break
    sleep 1
  done
  assert_eq "$(kubectl get pod "$pod" -n k-39-idli-robot -o name 2>/dev/null | grep -c .)" "0" "a plain delete DOES remove the Pod: the rule only guards evictions"
}

fixed() {
  kubectl rollout status deployment/idli -n k-39-idli-robot --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "idli Deployment is Ready again"
  assert_eq "$([ "$(allowed39)" -ge 1 ] 2>/dev/null && echo yes || echo no)" "yes" "the safety rule now allows at least 1 disruption"
  bash "$SCEN39/check.sh" >/dev/null 2>&1
  assert_eq "$?" "0" "check.sh says: done"
  bash "$SCEN39/evict.sh" >/dev/null 2>&1
  assert_eq "$?" "0" "the robot can now move a Pod"
}
