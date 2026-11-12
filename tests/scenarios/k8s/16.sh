#!/usr/bin/env bash
# Spec for scenario K16 (16-game-server-vip-node). Sourced by tests/scenarios/k8s.sh.
# Cluster-level (taints every node): run it alone, never in parallel with other scenarios.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-16-vip-node"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

# in_cluster_http cannot be used here: its curl Pod has no toleration, so while every node
# carries z2h-vip it would sit Pending forever. Same probe, plus the toleration.
tolerant_http() {
  local out code ov
  ov='{"spec":{"tolerations":[{"key":"z2h-vip","operator":"Equal","value":"true","effect":"NoSchedule"}]}}'
  out=$(in_cluster_pod "$1" "$ov" curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$2") || { printf 'ERR\n'; return 0; }
  code=$(printf '%s' "$out" | grep -o '^[0-9][0-9][0-9]' | head -n 1)
  printf '%s\n' "${code:-000}"
}

broken() {
  assert_eq "$(kubectl get pods -n k-16-vip-node -l app=game -o jsonpath='{.items[*].status.phase}' 2>&1)" "Pending Pending" "both game Pods are Pending"
  # Wording differs by version: "untolerated taint" (current) or "had taint" (older).
  assert_contains "$(kubectl get events -n k-16-vip-node 2>&1)" "taint" "the scheduler events mention the taint"
  assert_contains "$(kubectl get events -n k-16-vip-node 2>&1)" "z2h-vip" "the events name the z2h-vip taint"
}

fixed() {
  kubectl rollout status deployment/game -n k-16-vip-node --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "game Deployment rolled out"
  assert_eq "$(tolerant_http k-16-vip-node http://game)" "200" "game answers 200 inside the cluster"
}
