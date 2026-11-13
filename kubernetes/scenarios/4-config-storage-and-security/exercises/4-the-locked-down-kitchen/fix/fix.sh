#!/usr/bin/env bash
# S4.x4 fix: the checklist is complete AND the image really runs as a normal user (unprivileged nginx on 8080).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-45-lockdown"

settled() { [ "$(kubectl get deployment kitchen -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "2" ]; }

need_cluster
say "Completing the checklist and switching to an image that can obey it…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the kitchen to open" 180 settled \
  || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n k-45-lockdown --tail=3"
