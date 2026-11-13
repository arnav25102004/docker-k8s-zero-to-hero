#!/usr/bin/env bash
# S2.3 fix: the watchman tolerates the reserved signs.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-16-daemonset"

settled() {
  local nodes want ready
  nodes=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
  want=$(kubectl get daemonset watchman -n "$NS" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  ready=$(kubectl get daemonset watchman -n "$NS" -o jsonpath='{.status.numberReady}' 2>/dev/null)
  [ "${want:-0}" = "$nodes" ] && [ "${ready:-0}" = "$nodes" ]
}

need_cluster
say "Teaching the watchman to tolerate the reserved signs…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "a watchman at every gate" 180 settled \
  || die "Not every gate has a watchman yet. Check: kubectl get daemonset,pods -n $NS -o wide"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl get daemonset,pods -n $NS -o wide"
