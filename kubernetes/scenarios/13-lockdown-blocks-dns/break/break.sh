#!/usr/bin/env bash
# K13 break: a "security hardening" NetworkPolicy blocks the app's DNS lookups.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-13-lockdown"
PROBE="k-13-probe"

redis_ready() { [ "$(kubectl get pod -n "$NS" -l app=redis -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)" = "true" ]; }
pod_running() { [ "$(kubectl get pod "$2" -n "$1" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended failure: the app is up, but its visitor sees "not ready" and the log shows the failed lookup.
app_cannot_resolve() {
  kubectl get pod -n "$NS" -l app=showdown -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running || return 1
  kubectl logs -n "$NS" visitor 2>/dev/null | grep -q "not ready" || return 1
  kubectl logs -n "$NS" -l app=showdown --tail=50 2>&1 | grep -q "readiness failed"
}

# Does this cluster really enforce NetworkPolicy? Some don't (often Docker Desktop or a default minikube):
# there a policy is accepted and silently ignored, and this scenario would show nothing.
# Test: a client reaches a target Service; then a deny-all-egress policy goes on the client;
# if the client can STILL reach the target, nothing is enforcing policies.
probe_enforces() {
  local ip i enforced=1
  kubectl delete namespace "$PROBE" --ignore-not-found >/dev/null 2>&1
  kubectl create namespace "$PROBE" >/dev/null || return 2
  kubectl label namespace "$PROBE" z2h.scenario=k13 --overwrite >/dev/null
  kubectl apply -n "$PROBE" -f - >/dev/null <<'YAML' || return 2
apiVersion: v1
kind: Pod
metadata:
  name: target
  labels: {app: target}
spec:
  terminationGracePeriodSeconds: 1
  containers:
    - name: target
      image: busybox:1.36
      command: ["sh", "-c", "mkdir -p /www && echo ok > /www/index.html && httpd -f -p 80 -h /www"]
---
apiVersion: v1
kind: Service
metadata:
  name: target
spec:
  selector: {app: target}
  ports: [{port: 80}]
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  labels: {app: client}
spec:
  terminationGracePeriodSeconds: 1
  containers:
    - name: client
      image: busybox:1.36
      command: ["sleep", "3600"]
YAML
  wait_for "the probe Pods to start" 120 pod_running "$PROBE" target || return 2
  wait_for "the probe client to start" 120 pod_running "$PROBE" client || return 2
  ip=$(kubectl get svc target -n "$PROBE" -o jsonpath='{.spec.clusterIP}')
  # Baseline: before any policy the client must reach the target (by IP, so DNS is not involved).
  i=0
  while [ "$i" -lt 10 ] && ! kubectl exec -n "$PROBE" client -- wget -q -T 2 -O /dev/null "http://$ip/" >/dev/null 2>&1; do
    sleep 1
    i=$((i + 1))
  done
  [ "$i" -lt 10 ] || return 2
  kubectl apply -n "$PROBE" -f - >/dev/null <<'YAML' || return 2
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector:
    matchLabels: {app: client}
  policyTypes: [Egress]
YAML
  # Enforcement can take a moment to arrive: try up to 8 times. Only 2 failures in a row count
  # as "enforced" (one odd exec error must not pass for a blocked connection).
  i=0
  fails=0
  while [ "$i" -lt 8 ]; do
    if kubectl exec -n "$PROBE" client -- wget -q -T 1 -O /dev/null "http://$ip/" >/dev/null 2>&1; then
      fails=0
    else
      fails=$((fails + 1))
    fi
    if [ "$fails" -ge 2 ]; then
      enforced=0
      break
    fi
    sleep 1
    i=$((i + 1))
  done
  return "$enforced"
}

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9213 || die "Port 9213 is busy, so this scenario can't start. Free it (see above) and run break.sh again."

say "Checking that this cluster enforces NetworkPolicy (a quick check, about 15 seconds)…"
probe_enforces
rc=$?
delete_ns "$PROBE"
if [ "$rc" -eq 1 ]; then
  die "This cluster doesn't enforce NetworkPolicy (e.g. Docker Desktop, default minikube). Use kind, Killercoda or iximiuz for this scenario."
elif [ "$rc" -ne 0 ]; then
  die "The NetworkPolicy check couldn't finish. Run cleanup.sh and try again."
fi
ok "NetworkPolicy is enforced here."

fresh_ns "$NS" || die "Could not create the namespace $NS."
create_showdown_configmap "$NS" || die "Could not create the ConfigMap showdown-code."

say "Deploying Redis, the Cats vs Dogs app, a visitor and the lockdown policy…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "Redis to start (the first download can take a minute)" 180 redis_ready \
  || die "Redis didn't start. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 pod_running "$NS" visitor \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."
wait_for "the app to start and fail to look up Redis" 180 app_cannot_resolve \
  || die "Expected the app to be up but not ready, and it isn't. Run cleanup.sh and try again."

show_next \
  "Redis is running. The app is running too. Security hardened the network, and now the app says it is not ready and nobody can vote. The visitor sees it live: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
