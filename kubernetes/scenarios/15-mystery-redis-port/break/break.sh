#!/usr/bin/env bash
# K15 break: the Service "redis" exists BEFORE the worker Pod starts, so Kubernetes injects
# REDIS_PORT=tcp://<ip>:6379 into it and int() of that crashes the worker.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-15-mystery-env"

redis_ready() { [ "$(kubectl get pod -n "$NS" -l app=redis -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)" = "true" ]; }
# The intended failure: the worker keeps crashing.
crashing() { [ "$(pod_reason "$NS" app=score-worker)" = "CrashLoopBackOff" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying Redis, its Service and the score worker…"
# Alphabetical order: redis.yaml (with the Service) is applied before worker.yaml.
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "Redis to start (the first download can take a minute)" 180 redis_ready \
  || die "Redis didn't start. Run cleanup.sh and try again."

wait_for "the score worker to start crashing" 180 crashing \
  || die "The worker never reached CrashLoopBackOff. Run cleanup.sh and try again."

show_next \
  "Redis is running, but the score worker keeps crashing and restarting." \
  "kubectl get pods -n $NS"
