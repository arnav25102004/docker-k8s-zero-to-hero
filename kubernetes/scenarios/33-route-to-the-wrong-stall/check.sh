#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-33-gateway"
need_cluster
resolved=$(kubectl get httproute menu -n "$NS" -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)
if [ "$resolved" = "True" ] && check_rollouts "$NS" && check_visitor "$NS"; then
  ok "Both paths work: every route points at a Service that exists, and the visitor sees ✅."
  exit 0
fi
warn "Not yet: ResolvedRefs is '${resolved:-unknown}'. The route must point at Services that exist, and the visitor must see ✅ on both paths."
exit 1
