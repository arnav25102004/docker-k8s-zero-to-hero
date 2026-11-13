#!/usr/bin/env bash
# K46 fix: the database name is spelled right.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-46-3am"

settled() { check_rollouts "$NS" >/dev/null 2>&1; }

need_cluster
say "Fixing the database name…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the orders service to come up" 180 settled \
  || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl logs visitor -n k-46-3am --tail=3"
