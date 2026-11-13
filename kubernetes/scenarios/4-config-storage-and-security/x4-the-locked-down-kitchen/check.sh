#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-45-lockdown"
need_cluster
lvl=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
if [ "$lvl" != "restricted" ]; then
  warn "The namespace guard is not set to restricted any more (it is '${lvl:-gone}'). Switching the guard off is not a fix: put it back and fix the Pods instead."
  exit 1
fi
ready=$(kubectl get deployment kitchen -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
ready=${ready:-0}
if [ "$ready" -ge 2 ]; then
  ok "The locked-down kitchen is open: it passes the restricted level and the image really runs as a normal user."
  exit 0
fi
warn "Not yet: $ready of 2 Pods are Ready. Two things can keep it closed: the Pod Security checklist, and whether the image can obey it."
exit 1
