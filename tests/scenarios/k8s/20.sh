#!/usr/bin/env bash
# Spec for scenario K20 (20-surprise-limitrange-oom). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-20-limitrange"
NS20="k-20-limitrange"

# All last-terminated reasons / exit codes of the app Pods, space separated ("" when none yet).
last_reasons() { kubectl get pods -n "$NS20" -l app=showdown -o jsonpath='{range .items[*]}{.status.containerStatuses[0].lastState.terminated.reason}{" "}{end}' 2>/dev/null; }
last_exits() { kubectl get pods -n "$NS20" -l app=showdown -o jsonpath='{range .items[*]}{.status.containerStatuses[0].lastState.terminated.exitCode}{" "}{end}' 2>/dev/null; }

broken() {
  local i r="" e=""
  for i in $(seq 1 45); do
    r="$(last_reasons)"
    [ -n "${r// /}" ] && break
    sleep 2
  done
  e="$(last_exits)"
  # K08 ruling: the same kill is occasionally recorded as reason "Error" (still exit 137).
  case "$r" in *OOMKilled* | *Error*) r="OOMKilled-or-Error" ;; esac
  assert_eq "$r" "OOMKilled-or-Error" "the last terminated reason is OOMKilled (or Error, exit 137)"
  assert_contains "$e" "137" "exit code is 137"
  assert_eq "$(kubectl get pods -n "$NS20" -l app=showdown -o jsonpath='{.items[0].spec.containers[0].resources.limits.memory}' 2>&1)" "32Mi" "the Pod has limits.memory=32Mi"
  assert_eq "$(kubectl get deployment showdown -n "$NS20" -o jsonpath='{.spec.template.spec.containers[0].resources}' 2>&1)" "{}" "nobody wrote it: the Deployment has no resources section"
  assert_contains "$(kubectl get pod visitor -n "$NS20" -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>&1)" "32Mi" "the visitor Pod got the 32Mi default too"
}

fixed() {
  kubectl rollout status deployment/showdown -n "$NS20" --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out"
  assert_eq "$(in_cluster_http "$NS20" http://showdown/healthz)" "200" "/healthz returns 200 (the test curl Pod runs under the 32Mi default)"
  assert_eq "$(kubectl get pods -n "$NS20" -l app=showdown -o jsonpath='{.items[0].spec.containers[0].resources.limits.memory}' 2>&1)" "128Mi" "the Pod now has limits.memory=128Mi"
  assert_eq "$(kubectl get pods -n "$NS20" -l app=showdown --no-headers 2>&1 | wc -l | tr -d ' ')" "2" "exactly 2 app Pods are left"
}
