#!/usr/bin/env bash
# Spec for scenario K33 (33-route-to-the-wrong-stall). Needs the Gateway controller (scripts/install-gateway.sh). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-33-gateway"
CHECK33="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/3-services-ingress-and-networking/4-route-to-the-wrong-stall" && pwd)/check.sh"
if ! kubectl get gatewayclass eg >/dev/null 2>&1; then
  printf '  installing the Gateway controller (Envoy Gateway): a couple of minutes the first time\n'
  bash "$REPO/scripts/install-gateway.sh" >/dev/null 2>&1 || { printf 'scripts/install-gateway.sh failed: run it by hand to see why\n' >&2; exit 1; }
fi

resolved33() { kubectl get httproute menu -n k-33-gateway -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null; }

check_passes33() {
  local i
  for i in $(seq 1 20); do
    bash "$CHECK33" >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

broken() {
  assert_eq "$(resolved33)" "False" "the route has an unresolved backend (ResolvedRefs is False)"
  assert_contains "$(kubectl get httproute menu -n k-33-gateway -o jsonpath='{.status.parents[0].conditions[*].message}' 2>&1)" "dossa" "the route's status names the missing Service"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK33"
}

fixed() {
  assert_eq "$(resolved33)" "True" "every backend now resolves"
  check_passes33
  assert_eq "$?" "0" "check.sh says: done (both paths answer)"
}
