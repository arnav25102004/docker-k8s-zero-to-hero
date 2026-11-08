#!/usr/bin/env bash
# Spec for scenario K08 (08-ai-trainer-oomkilled). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-08-oomkilled"

# Last terminated reason / restart count of the trainer container ("" when none yet).
last_reason() { kubectl get pod -n k-08-oomkilled -l app=trainer -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null; }
restarts() { kubectl get pod -n k-08-oomkilled -l app=trainer -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null; }

broken() {
  local i r=""
  for i in $(seq 1 45); do
    r="$(last_reason)"
    [ -n "$r" ] && break
    sleep 2
  done
  # Known runtime race: the same kill is occasionally recorded as reason "Error" (still exit 137).
  case "$r" in OOMKilled | Error) r="OOMKilled-or-Error" ;; esac
  assert_eq "$r" "OOMKilled-or-Error" "lastState.terminated.reason is OOMKilled (or Error, exit 137)"
  assert_eq "$(kubectl get pod -n k-08-oomkilled -l app=trainer -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.exitCode}' 2>&1)" "137" "exit code is 137"
  assert_contains "$(kubectl logs -n k-08-oomkilled -l app=trainer --previous 2>&1)" "epoch 3/6" "the previous run's logs reach epoch 3"
}

fixed() {
  local i out="" r1 r2
  kubectl rollout status deployment/trainer -n k-08-oomkilled --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "trainer Deployment rolled out (Ready 1/1)"
  for i in $(seq 1 30); do
    out="$(kubectl logs -n k-08-oomkilled -l app=trainer 2>&1)"
    case "$out" in *"model trained"*) break ;; esac
    sleep 2
  done
  assert_contains "$out" "model trained" "logs contain model trained"
  r1="$(restarts)"
  sleep 20
  r2="$(restarts)"
  assert_eq "$r2" "$r1" "restartCount unchanged for 20 s"
  assert_eq "$r2" "0" "the fixed Pod never restarted"
  assert_eq "$(last_reason)" "" "no new OOMKilled (no lastState)"
}
