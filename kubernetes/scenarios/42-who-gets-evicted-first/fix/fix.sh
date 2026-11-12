#!/usr/bin/env bash
# K42 fix: cache is Guaranteed, web is Burstable, batch is BestEffort.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-42-qos"

settled() { for d in cache web batch; do [ "$(kubectl rollout status deployment/$d -n "$NS" --timeout=2s >/dev/null 2>&1; echo $?)" = "0" ] || return 1; done; }

need_cluster
say "Giving each workload the class it deserves…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
# apply only adds/changes fields; the batch job must LOSE its resources block
kubectl patch deployment batch -n "$NS" --type json -p '[{"op":"remove","path":"/spec/template/spec/containers/0/resources"}]' >/dev/null 2>&1 || true

wait_for "all three to settle" 180 settled \
  || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh"
