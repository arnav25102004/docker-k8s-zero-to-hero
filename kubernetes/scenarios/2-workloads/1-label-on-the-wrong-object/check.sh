#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-32-wrong-object"
need_cluster
addrs=$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=samosa -o jsonpath='{..addresses}' 2>/dev/null)
if [ -z "$addrs" ]; then
  warn "Not yet: the samosa Service still has no endpoints. Nobody can reach the fryers."
  exit 1
fi
if kubectl logs visitor -n "$NS" --tail=2 2>/dev/null | grep -q "✅"; then
  ok "Samosas are flowing. The Service found its Pods, and the visitor is happily fed."
  exit 0
fi
warn "The Service has endpoints, but the visitor hasn't been served yet. Give it a few seconds and run this again."
exit 1
