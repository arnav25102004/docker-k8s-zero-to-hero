#!/usr/bin/env bash
# Spec for scenario K15 (15-mystery-redis-port). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-15-mystery-env"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  assert_eq "$(pod_reason k-15-mystery-env app=score-worker)" "CrashLoopBackOff" "the score worker is in CrashLoopBackOff"
  local prev
  prev="$(kubectl logs -n k-15-mystery-env -l app=score-worker --previous 2>&1)"
  assert_contains "$prev" "invalid literal for int()" "logs --previous shows invalid literal for int()"
  assert_contains "$prev" "tcp://" "logs --previous shows the tcp:// value"
}

fixed() {
  kubectl rollout status deployment/score-worker -n k-15-mystery-env --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "score-worker Deployment rolled out"
  assert_contains "$(kubectl logs -n k-15-mystery-env -l app=score-worker 2>&1)" "worker connected to redis:6379" "the worker connected to redis:6379"
}
