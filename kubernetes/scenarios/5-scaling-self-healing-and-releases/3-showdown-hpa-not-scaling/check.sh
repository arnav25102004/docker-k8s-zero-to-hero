#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-25-hpa"
need_cluster
util=$(kubectl get hpa showdown -n "$NS" -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
req=$(kubectl get deployment showdown -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
case "$util" in
  '' | *[!0-9]*) warn "Not yet: the autoscaler still shows <unknown> (CPU request: ${req:-none}). It re-reads every 15 seconds."; exit 1 ;;
esac
ok "The autoscaler can read CPU now: it sees ${util}% of the request (${req:-?})."
exit 0
