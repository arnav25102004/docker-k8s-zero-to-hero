#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-11-bad-rollout"
need_cluster
ver=$(kubectl get deployment showdown -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_VERSION")].value}' 2>/dev/null)
ready=$(kubectl get deployment showdown -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
total=$(kubectl get pods -n "$NS" -l app=showdown --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$ver" = "1.0.0" ] && [ "${ready:-0}" = "3" ] && [ "$total" = "3" ]; then
  ok "The bad release is rolled back: version 1.0.0, 3 of 3 Pods Ready, none left over."
  exit 0
fi
warn "Not yet: version is '${ver:-?}' (want 1.0.0), ${ready:-0} Pods Ready (want 3), $total Pods listed (want 3)."
exit 1
