#!/usr/bin/env bash
# Spec for scenario K25 (25-showdown-hpa-not-scaling). Cluster-level (metrics-server): run it alone.
# Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-25-hpa"
NS25="k-25-hpa"

broken() {
  assert_contains "$(kubectl get hpa showdown -n "$NS25" 2>&1)" "<unknown>" "the HPA TARGETS column shows <unknown>"
  assert_contains "$(kubectl describe hpa showdown -n "$NS25" 2>&1)" "missing request for cpu" "the HPA events/conditions say the CPU request is missing"
  assert_eq "$(kubectl get deployment showdown -n "$NS25" -o jsonpath='{.spec.template.spec.containers[0].resources}' 2>&1)" "{}" "the Deployment has no resources section"
}

fixed() {
  local i=0 cur="" util="" many isnum
  while [ "$i" -lt 240 ]; do
    cur=$(kubectl get hpa showdown -n "$NS25" -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
    util=$(kubectl get hpa showdown -n "$NS25" -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
    [ -n "$util" ] && [ "${cur:-1}" -ge 2 ] && break
    sleep 3
    i=$((i + 3))
  done
  kubectl rollout status deployment/showdown -n "$NS25" --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out"
  many="no"
  [ "${cur:-1}" -ge 2 ] 2>/dev/null && many="yes"
  assert_eq "$many" "yes" "status.currentReplicas is at least 2 (got ${cur:-none})"
  case "$util" in '' | *[!0-9]*) util="" ;; esac
  assert_contains "$(kubectl get hpa showdown -n "$NS25" 2>&1)" "%/50%" "the TARGETS column is numeric"
  isnum="no"
  [ -n "$util" ] && isnum="yes"
  assert_eq "$isnum" "yes" "averageUtilization is a number"
  assert_eq "$(kubectl get deployment showdown -n "$NS25" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>&1)" "100m" "the Deployment requests 100m CPU"
}
