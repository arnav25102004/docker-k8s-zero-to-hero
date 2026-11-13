#!/usr/bin/env bash
# Spec for scenario K30 (30-friday-5pm-outage). Sourced by tests/scenarios/k8s.sh.
# Adds a third cycle: fix 1 by hand (kubectl set image), then fix.sh, then fixed().
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-30-friday"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

NS30="k-30-friday"

# in_cluster_sh NS SCRIPT: run a small sh script in a throwaway curl Pod, print its output.
in_cluster_sh() {
  in_cluster_pod "$1" "" sh -c "$2"
}

broken() {
  local reason ip
  reason="$(pod_reason "$NS30" app=redis)"
  local pulling=no
  case "$reason" in ImagePullBackOff|ErrImagePull) pulling=yes ;; esac
  assert_eq "$pulling" "yes" "the redis Pod is stuck pulling its image (reason: $reason)"
  assert_eq "$(in_cluster_http "$NS30" http://showdown/healthz)" "000" "http://showdown/healthz gets no answer through the Service"
  ip="$(kubectl get pod -n "$NS30" -l app=showdown -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)"
  assert_contains "$(in_cluster_sh "$NS30" "curl -s --max-time 5 http://$ip:8080/api/info")" '"storage": "memory"' "a showdown Pod (by Pod IP) stores votes in memory"
}

fixed() {
  kubectl rollout status deployment/redis -n "$NS30" --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "redis Deployment rolled out"
  kubectl rollout status deployment/showdown -n "$NS30" --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out"
  assert_eq "$(in_cluster_http_wait "$NS30" http://showdown/healthz 200)" "200" "showdown answers 200 on /healthz through the Service"
  assert_contains "$(in_cluster_sh "$NS30" "curl -s --max-time 5 http://showdown/api/info")" '"storage": "redis"' "/api/info says storage redis"
  # Persistence across the 2 replicas: vote for cats once, then read the count 6 times
  # through the Service (spread over both Pods). The visitor only ever votes for dogs.
  local out before
  out="$(in_cluster_sh "$NS30" '
    c() { curl -s --max-time 5 http://showdown/api/results | grep -o "\"cats\": [0-9]*" | grep -o "[0-9]*$"; }
    b=$(c); echo "before=$b"
    curl -s --max-time 5 "http://showdown/api/vote?option=cats" >/dev/null
    for i in 1 2 3 4 5 6; do echo "after=$(c)"; done')"
  before="$(printf '%s\n' "$out" | sed -n 's/^before=//p')"
  assert_eq "$(printf '%s\n' "$out" | grep -c "^after=$((before + 1))\$")" "6" "a cat vote sticks: 6 reads through the Service all show cats=$((before + 1))"
}

# Third cycle (Review Focus #5): on stage, the presenter fixes the image by hand, then runs
# fix.sh, which must still apply the other two fixes. Wraps the harness's two-cycle runner.
eval "_k30_two_cycles() $(declare -f run_cycle_k8s | sed 1d)"
run_cycle_k8s() {
  local dir="$1" id="$2"
  _k30_two_cycles "$@" || return 1
  shift 2
  printf '  -- cycle 3/3 (fix 1 by hand, then fix.sh)\n'
  _step cleanup 3 "$(_script "$dir/cleanup.py" "$dir/cleanup.sh")" || return 1
  _step break 3 "$(_script "$dir/break/run.py" "$dir/break/break.sh")" || return 1
  _check broken 3 broken || return 1
  kubectl set image deployment/redis -n "$NS30" redis=redis:7.4.12-alpine >/dev/null 2>&1 \
    || { printf '  FAILED at step: kubectl set image (cycle 3)\n'; return 1; }
  kubectl rollout status deployment/redis -n "$NS30" --timeout=180s >/dev/null 2>&1 \
    || { printf '  FAILED at step: redis rollout after set image (cycle 3)\n'; return 1; }
  _step fix 3 "$(_script "$dir/fix/run.py" "$dir/fix/fix.sh")" || return 1
  _check fixed 3 fixed || return 1
  _step "final cleanup" 3 "$(_script "$dir/cleanup.py" "$dir/cleanup.sh")" || return 1
  nothing_left_k8s "$id" "$@" || { printf '  FAILED at step: nothing-left check (cycle 3)\n'; return 1; }
}
