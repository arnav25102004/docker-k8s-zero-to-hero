#!/usr/bin/env bash
# Spec for scenario K37 (37-pod-that-will-not-leave). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-37-stuck-pod"
CHECK37="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/37-pod-that-will-not-leave" && pwd)/check.sh"

broken() {
  assert_eq "$([ -n "$(kubectl get pod old-stall -n k-37-stuck-pod -o jsonpath='{.metadata.deletionTimestamp}' 2>&1)" ] && echo yes || echo no)" "yes" "the Pod has been asked to delete (it has a deletionTimestamp)"
  assert_contains "$(kubectl get pod old-stall -n k-37-stuck-pod -o jsonpath='{.metadata.finalizers}' 2>&1)" "cleanup-lock" "a finalizer is holding it"
  assert_contains "$(kubectl get pods -n k-37-stuck-pod 2>&1)" "Terminating" "kubectl shows it as Terminating"
  # The tempting wrong fix: a force delete does not lift a finalizer.
  kubectl delete pod old-stall -n k-37-stuck-pod --grace-period=0 --force >/dev/null 2>&1
  sleep 3
  assert_eq "$(kubectl get pod old-stall -n k-37-stuck-pod -o name 2>/dev/null)" "pod/old-stall" "a force delete did NOT remove it (the finalizer still holds)"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK37"
}

fixed() {
  local i
  for i in $(seq 1 30); do
    kubectl get pod old-stall -n k-37-stuck-pod >/dev/null 2>&1 || break
    sleep 2
  done
  assert_eq "$(kubectl get pod old-stall -n k-37-stuck-pod -o name 2>/dev/null)" "" "the Pod is gone"
  bash "$CHECK37" >/dev/null 2>&1
  assert_eq "$?" "0" "check.sh says: done"
}
