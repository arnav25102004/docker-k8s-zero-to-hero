#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-43-van"
need_cluster
lvl=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
if [ "$lvl" != "baseline" ]; then
  warn "The namespace guard is not set to baseline any more (it is '${lvl:-gone}'). Switching the guard off is not a fix: put it back and fix the Pods instead."
  exit 1
fi
ready=$(kubectl get deployment van -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
ready=${ready:-0}
if [ "$ready" -ge 2 ]; then
  ok "The chai van is open: the Pods were admitted and are Ready, and the namespace guard is still on."
  exit 0
fi
warn "Not yet: $ready of 2 Pods are Ready. The namespace's Pod Security level decides which Pods it will accept."
exit 1
