#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-27-helm"
need_cluster
tag=$(kubectl get deployment stall -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
if [ "${tag##*:}" = "1.0.0" ] && check_rollouts "$NS" && check_visitor "$NS"; then
  ok "The stall runs the good image again ($tag), every Pod is Ready, and the visitor sees ✅."
  exit 0
fi
warn "Not yet: the stall's image is '${tag:-none}' (want a working 1.0.0), or Pods are not all Ready."
exit 1
