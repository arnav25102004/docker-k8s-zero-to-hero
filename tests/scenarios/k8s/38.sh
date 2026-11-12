#!/usr/bin/env bash
# Spec for scenario K38 (38-applied-here-looking-there). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-38-night-canteen"
CHECK38="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/38-applied-here-looking-there" && pwd)/check.sh"

current_ns38() { local n; n="$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)"; echo "${n:-default}"; }

broken() {
  kubectl rollout status deployment/night-canteen -n k-38-night-canteen --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "night-canteen is Ready (in its own namespace)"
  assert_eq "$([ "$(current_ns38)" != "k-38-night-canteen" ] && echo yes || echo no)" "yes" "your kubectl is not looking in that namespace"
  assert_eq "$(kubectl get pods -o name 2>&1 | grep -c night-canteen)" "0" "a plain 'kubectl get pods' does not show the canteen"
  assert_contains "$(kubectl get deployments -A 2>&1)" "night-canteen" "'kubectl get deployments -A' finds it"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK38"
  assert_eq "$(in_cluster_http_wait k-38-night-canteen http://night-canteen 200)" "200" "the canteen itself is serving happily"
}

fixed() {
  assert_eq "$(current_ns38)" "k-38-night-canteen" "the current context now points at the canteen's namespace"
  assert_eq "$(kubectl get pods -o name 2>&1 | grep -c night-canteen)" "2" "a plain 'kubectl get pods' now shows both canteen Pods"
  bash "$CHECK38" >/dev/null 2>&1
  assert_eq "$?" "0" "check.sh says: done"
}
