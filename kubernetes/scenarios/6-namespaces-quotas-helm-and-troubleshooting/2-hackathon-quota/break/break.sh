#!/usr/bin/env bash
# S6.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-19-hackathon"

# The quota must be "live" (its totals filled in) before any Pod is created, otherwise the
# first Pods could slip in without being counted.
quota_live() { [ -n "$(kubectl get resourcequota hackathon-quota -n "$NS" -o jsonpath='{.status.hard.requests\.cpu}' 2>/dev/null)" ]; }

# The intended failure: the ReplicaSet's events say it was refused by the quota.
refused() { kubectl get events -n "$NS" 2>/dev/null | grep -q "failed quota"; }

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9219 || die "Port 9219 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Setting up the hackathon namespace…"
kubectl apply -f "$HERE/setup.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
wait_for "the namespace setup to finish" 60 quota_live \
  || die "The namespace setup didn't finish. Run cleanup.sh and try again."

say "Deploying the hackathon dashboard and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the dashboard to misbehave" 180 refused \
  || die "Expected the dashboard to fail, but didn't see it. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

scene_set
