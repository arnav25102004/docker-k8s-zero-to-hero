#!/usr/bin/env bash
# S6.3 fix: roll the release back to revision 1 with Helm.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-27-helm"

settled() { check_rollouts "$NS" >/dev/null 2>&1; }

need_cluster
command -v helm >/dev/null 2>&1 || die "This scenario uses Helm and it isn't installed. macOS: brew install helm · Windows: winget install Helm.Helm · Linux: https://helm.sh/docs/intro/install/"
say "Rolling the release back to revision 1…"
helm rollback stall 1 -n "$NS" --wait --timeout 3m >/dev/null || die "helm rollback failed. Check: helm history stall -n $NS"

wait_for "the Pods to settle" 120 settled || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   helm history stall -n $NS"
