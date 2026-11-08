#!/usr/bin/env bash
# Spec for scenario K03 (03-showdown-crashloop). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-03-crashloop"
# pod_reason lives in the scenarios lib (the harness itself does not source it).
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  assert_eq "$(pod_reason k-03-crashloop app=showdown)" "CrashLoopBackOff" "showdown Pod is in CrashLoopBackOff"
  assert_contains "$(kubectl logs -n k-03-crashloop -l app=showdown --previous 2>&1)" "ValueError" "logs --previous shows the ValueError"
}

fixed() {
  kubectl rollout status deployment/showdown -n k-03-crashloop --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out"
  assert_eq "$(in_cluster_http k-03-crashloop http://showdown/healthz)" "200" "showdown answers 200 on /healthz inside the cluster"
}
