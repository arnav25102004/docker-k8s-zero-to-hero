#!/usr/bin/env bash
# K39 fix: the safety rule now allows one Pod to be away at a time (minAvailable: 1 of 2).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-39-idli-robot"

one_allowed() { [ "$(kubectl get pdb idli-pdb -n "$NS" -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null)" -ge 1 ] 2>/dev/null; }

need_cluster
say "Loosening the safety rule: keep at least 1 of 2 Pods, not 2 of 2…"
kubectl apply -f "$HERE/pdb.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the rule to allow one Pod to move" 60 one_allowed \
  || die "The rule still allows nothing. Check: kubectl get pdb -n $NS"

show_next "✅ Fixed. Send the robot in again:" \
  "./evict.sh   ·   ./check.sh"
