#!/usr/bin/env bash
# S2.4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-28-job"

redis_ready() { [ "$(kubectl get pod -n "$NS" -l app=redis -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)" = "true" ]; }
# The intended failure: the Job has used up its retries.
job_gave_up() { [ "$(kubectl get job leaderboard-reset -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)" = "True" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying Redis…"
kubectl apply -f "$HERE/redis.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
wait_for "Redis to start (the first download can take a minute)" 180 redis_ready \
  || die "Redis didn't start. Run cleanup.sh and try again."

say "Putting some scores on the leaderboard…"
kubectl exec -n "$NS" deploy/redis -- redis-cli ZADD scores 120 Lakshmi 95 Ravi 80 Meera 60 Priya 45 Arjun >/dev/null \
  || die "Could not add the scores. Run cleanup.sh and try again."

say "Running the nightly reset Job…"
kubectl apply -f "$HERE/script.yaml" -f "$HERE/job.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

# Retries wait 10 s, then 20 s: about half a minute in all (longer if the Python image is still downloading).
wait_for "the Job to finish its attempts (about half a minute; the first download can take longer)" 180 job_gave_up \
  || die "The Job never finished. Run cleanup.sh and try again."

show_next \
  "The scores were meant to be reset overnight. They weren't, and the Job has stopped trying." \
  "kubectl get job,pods -n $NS"
