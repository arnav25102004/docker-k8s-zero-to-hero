#!/usr/bin/env bash
# Spec for scenario K29 (29-log-sidecar-half-ready). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-29-sidecar"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

NS29="k-29-sidecar"

# ready/total containers of the newest notice Pod, e.g. "1/2". After a fix the old Pod can linger,
# terminating, next to its replacement (the log-shipper ignores the stop signal), so .items[0]
# may be the old one: sort by age and take the last.
notice_ready_count() {
  local r total=0 ready=0 x
  r="$(kubectl get pods -n "$NS29" -l app=notice --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[-1:].status.containerStatuses[*]}{.ready}{" "}{end}' 2>/dev/null)"
  for x in $r; do
    total=$((total + 1))
    [ "$x" = "true" ] && ready=$((ready + 1))
  done
  printf '%s/%s\n' "$ready" "$total"
}

broken() {
  assert_eq "$(notice_ready_count)" "1/2" "the notice Pod is 1/2 Ready"
  assert_eq "$(in_cluster_http "$NS29" http://notice)" "000" "the Service has no ready Pod, so nobody gets an answer"
}

fixed() {
  kubectl rollout status deployment/notice -n "$NS29" --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "notice Deployment rolled out"
  assert_eq "$(notice_ready_count)" "2/2" "the notice Pod is 2/2 Ready"
  assert_eq "$(in_cluster_http_wait "$NS29" http://notice 200)" "200" "the board answers 200 inside the cluster"
  local i=0 out=""
  while [ "$i" -lt 20 ]; do
    out="$(kubectl logs -n "$NS29" -l app=notice -c log-shipper --tail=50 2>&1)"
    case "$out" in *'"GET / HTTP/1.1" 200'*) break ;; esac
    sleep 1
    i=$((i + 1))
  done
  assert_contains "$out" '"GET / HTTP/1.1" 200' "the log-shipper logs show an access line"
}
