#!/usr/bin/env bash
# Spec for scenario K41 (41-autoscaler-pointing-at-nobody). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-41-hpa-target"
CHECK41="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/41-autoscaler-pointing-at-nobody" && pwd)/check.sh"

ready41() { local r; r="$(kubectl get deployment lassi -n k-41-hpa-target -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }
rsmsg41() { kubectl get rs -n k-41-hpa-target -l app=lassi -o jsonpath='{.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}' 2>&1; }

able41() { kubectl get hpa lassi -n k-41-hpa-target -o jsonpath='{.status.conditions[?(@.type=="AbleToScale")].status}' 2>/dev/null; }
hpamsg41() { kubectl get hpa lassi -n k-41-hpa-target -o jsonpath='{.status.conditions[*].message}' 2>&1; }

broken() {
  assert_eq "$(ready41)" "1" "the lassi stall itself is serving"
  assert_eq "$(able41)" "False" "the autoscaler cannot scale"
  assert_contains "$(hpamsg41)" "lasi" "the autoscaler's message names the missing target"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK41"
}

fixed() {
  local i
  for i in $(seq 1 30); do [ "$(able41)" = "True" ] && break; sleep 3; done
  assert_eq "$(able41)" "True" "the autoscaler found its target"
  assert_eq "$(bash "$CHECK41" >/dev/null 2>&1; echo $?)" "0" "check.sh says: done"
}
