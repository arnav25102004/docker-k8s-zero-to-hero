#!/usr/bin/env bash
# Spec for scenario K16 (16-watchman-skipped-a-gate). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-16-daemonset"
CHECK16="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/16-watchman-skipped-a-gate" && pwd)/check.sh"

nodes16() { kubectl get nodes --no-headers | wc -l | tr -d ' '; }
want16() { local r; r="$(kubectl get daemonset watchman -n k-16-daemonset -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)"; echo "${r:-0}"; }
ready16() { local r; r="$(kubectl get daemonset watchman -n k-16-daemonset -o jsonpath='{.status.numberReady}' 2>/dev/null)"; echo "${r:-0}"; }

broken() {
  local n; n="$(nodes16)"
  assert_eq "$([ "$(want16)" -lt "$n" ] && echo yes || echo no)" "yes" "the DaemonSet wants fewer watchmen than there are nodes ($(want16) of $n)"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK16"
}

fixed() {
  local n i; n="$(nodes16)"
  for i in $(seq 1 60); do [ "$(ready16)" = "$n" ] && break; sleep 3; done
  assert_eq "$(want16)" "$n" "the DaemonSet now wants one watchman per node"
  assert_eq "$(ready16)" "$n" "every watchman is Ready"
  assert_eq "$(bash "$CHECK16" >/dev/null 2>&1; echo $?)" "0" "check.sh says: done"
}
