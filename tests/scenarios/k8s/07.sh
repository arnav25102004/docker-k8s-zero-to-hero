#!/usr/bin/env bash
# Spec for scenario K07 (07-showdown-slow-start). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-07-slow-start"

# restartCount of the showdown container ("" when there is no Pod yet).
restarts() { kubectl get pod -n k-07-slow-start -l app=showdown -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null; }

broken() {
  local i n=0
  for i in $(seq 1 45); do
    n="$(restarts)"
    [ "${n:-0}" -ge 2 ] 2>/dev/null && break
    sleep 2
  done
  [ "${n:-0}" -ge 2 ] 2>/dev/null && n=2
  assert_eq "$n" "2" "restartCount reached 2 within 90 s"
  assert_contains "$(kubectl get events -n k-07-slow-start 2>&1)" "Liveness probe failed" "events show Liveness probe failed"
  assert_contains "$(kubectl logs -n k-07-slow-start -l app=showdown --previous 2>&1)" "simulating slow startup" "logs show the slow startup"
}

fixed() {
  local r1 r2
  kubectl rollout status deployment/showdown -n k-07-slow-start --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out (Ready 1/1)"
  assert_eq "$(in_cluster_http k-07-slow-start http://showdown/healthz)" "200" "showdown answers 200 via the Service"
  r1="$(restarts)"
  sleep 30
  r2="$(restarts)"
  assert_eq "$r2" "$r1" "restartCount unchanged for 30 s after Ready"
  assert_eq "$r2" "0" "the fixed Pod never restarted"
}
