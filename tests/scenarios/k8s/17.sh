#!/usr/bin/env bash
# Spec for scenario K17 (17-ai-trainer-needs-gpu). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-17-needs-gpu"

broken() {
  local i out=""
  for i in $(seq 1 30); do
    out="$(kubectl get pods -n k-17-needs-gpu -l app=trainer --no-headers 2>&1)"
    case "$out" in *" Pending "*) break ;; esac
    sleep 2
  done
  assert_contains "$out" "Pending" "the trainer Pod is Pending"
  # The scheduler writes the FailedScheduling event a moment after the Pod shows Pending.
  for i in $(seq 1 30); do
    out="$(kubectl describe pod -n k-17-needs-gpu -l app=trainer 2>&1)"
    case "$out" in *"didn't match Pod's node affinity/selector"*) break ;; esac
    sleep 2
  done
  assert_contains "$out" "didn't match Pod's node affinity/selector" "events say the Pod's node affinity/selector didn't match"
}

fixed() {
  local i out=""
  kubectl rollout status deployment/trainer -n k-17-needs-gpu --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "trainer Deployment rolled out (Ready 1/1)"
  for i in $(seq 1 30); do
    out="$(kubectl logs -n k-17-needs-gpu -l app=trainer 2>&1)"
    case "$out" in *"model trained"*) break ;; esac
    sleep 2
  done
  assert_contains "$out" "model trained" "logs contain model trained"
}
