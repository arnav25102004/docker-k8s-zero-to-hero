#!/usr/bin/env bash
# Spec for scenario K19 (19-hackathon-quota). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-19-hackathon"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

# in_cluster_http cannot be used here: the namespace quota refuses any Pod without
# requests and limits, so its curl Pod would be rejected. Same probe, with resources.
quota_http() {
  local out code ov
  # The container (command included) is defined in the overrides, which replace the generated one.
  ov='{"spec":{"containers":[{"name":"@NAME@","image":"curlimages/curl:8.11.1","command":["curl","-s","-o","/dev/null","-w","%{http_code}","--max-time","5","'"$2"'"],"resources":{"requests":{"cpu":"10m","memory":"8Mi"},"limits":{"cpu":"50m","memory":"32Mi"}}}]}}'
  out=$(in_cluster_pod "$1" "$ov") || { printf 'ERR\n'; return 0; }
  code=$(printf '%s' "$out" | grep -o '^[0-9][0-9][0-9]' | head -n 1)
  printf '%s\n' "${code:-000}"
}

broken() {
  assert_eq "$(kubectl get pods -n k-19-hackathon -l app=dashboard -o name 2>&1)" "" "no dashboard Pods exist"
  assert_contains "$(kubectl get deployment dashboard -n k-19-hackathon 2>&1)" "0/2" "the Deployment shows 0/2"
  # Wording differs a little by version: "failed quota" (current) plus "must specify".
  assert_contains "$(kubectl describe rs -n k-19-hackathon -l app=dashboard 2>&1)" "failed quota" "the ReplicaSet events say failed quota"
}

fixed() {
  kubectl rollout status deployment/dashboard -n k-19-hackathon --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "dashboard Deployment rolled out"
  assert_eq "$(kubectl get deployment dashboard -n k-19-hackathon -o jsonpath='{.status.readyReplicas}' 2>&1)" "2" "2 of 2 replicas are Ready"
  assert_contains "$(kubectl describe quota -n k-19-hackathon 2>&1)" "110m" "describe quota shows the used CPU requests (110m)"
  assert_eq "$(quota_http k-19-hackathon http://dashboard)" "200" "dashboard answers 200 inside the cluster"
}
