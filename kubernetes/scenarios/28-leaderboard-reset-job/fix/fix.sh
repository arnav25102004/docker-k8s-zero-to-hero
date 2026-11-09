#!/usr/bin/env bash
# K28 fix: a Job's Pod template can't be edited after creation, so delete the Job and create it again.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-28-job"

need_cluster
say "Deleting the failed Job (its Pod template is immutable) and creating it again…"
# Editing spec.template of an existing Job is refused by Kubernetes, so delete and re-create.
kubectl delete job leaderboard-reset -n "$NS" --ignore-not-found >/dev/null || die "Could not delete the Job."
kubectl apply -f "$HERE/job.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Waiting for the Job to complete…"
kubectl wait --for=condition=complete job/leaderboard-reset -n "$NS" --timeout=120s >/dev/null \
  || die "The Job didn't complete. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get job -n $NS" \
  "kubectl logs job/leaderboard-reset -n $NS"
