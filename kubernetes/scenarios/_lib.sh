#!/usr/bin/env bash
# Shared helpers for the Kubernetes break/fix scenarios. Sourced (never executed)
# by break.sh, fix.sh and cleanup.sh. Works on bash 3.2 (macOS) and newer.
#
# Source it with an absolute path built from the script's own location:
#   break/ and fix/ scripts:  source "$(cd "$(dirname "$0")/../.." && pwd)/_lib.sh"
#   cleanup.sh:               source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"
#
# Reuses say/ok/warn/die/wait_for/show_next from the Docker track. (need_docker,
# scenario_cleanup and ensure_image from there are not used.)

_K8S_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../docker/scenarios/_lib.sh
source "$_K8S_LIB_DIR/../../docker/scenarios/_lib.sh"

# Stop early, with one friendly line, when there is no usable cluster.
need_cluster() {
  command -v kubectl >/dev/null 2>&1 || die "kubectl isn't installed. See 00-setup."
  if ! kubectl get --raw /readyz >/dev/null 2>&1; then
    die "Can't reach a Kubernetes cluster. Check: kubectl config current-context"
  fi
}

# delete_ns NS...: delete namespaces and wait (up to 120 s each) until they are
# really gone, so an immediate re-create works. Silent, always returns 0.
delete_ns() {
  local ns i
  for ns in "$@"; do
    kubectl delete namespace "$ns" --ignore-not-found --wait=false >/dev/null 2>&1
    i=0
    while [ "$i" -lt 120 ] && kubectl get namespace "$ns" >/dev/null 2>&1; do
      sleep 1
      i=$((i + 1))
    done
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
      warn "Namespace $ns is still terminating after 120s. Check: kubectl get namespace $ns"
    fi
  done
  return 0
}

# die_if_k16_taint: stop at once if K16's z2h-vip taint is still on a node (every other
# scenario's Pods would sit Pending). Called by fresh_ns; K16's own break.sh runs its
# cleanup (which removes the taint) before it gets to fresh_ns, so it is not blocked.
die_if_k16_taint() {
  if kubectl get nodes -o jsonpath='{range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}' 2>/dev/null | grep -q '^z2h-vip$'; then
    die "The nodes still carry the z2h-vip taint from K16. Run kubernetes/scenarios/16-game-server-vip-node/cleanup.sh (or: kubectl taint nodes --all z2h-vip-) and try again."
  fi
}

# fresh_ns NS...: delete (and wait for) then create each namespace, labelled
# z2h.scenario=<kNN> taken from the k-NN- prefix.
fresh_ns() {
  local ns id i
  die_if_k16_taint
  for ns in "$@"; do
    delete_ns "$ns"
    kubectl create namespace "$ns" >/dev/null || return 1
    id="k${ns#k-}"
    id="${id%%-*}"
    kubectl label namespace "$ns" "z2h.scenario=$id" --overwrite >/dev/null || return 1
    # The "default" ServiceAccount is created a moment later by a controller; Pods created
    # straight away would be refused ("serviceaccount default not found"). Wait for it.
    i=0
    while ! kubectl get serviceaccount default -n "$ns" >/dev/null 2>&1; do
      i=$((i + 1))
      [ "$i" -gt 30 ] && return 1
      sleep 1
    done
  done
}

# stop_port_forwards NS...: kill leftover "kubectl port-forward -n NS ..." processes.
stop_port_forwards() {
  local ns
  for ns in "$@"; do
    pkill -f "port-forward -n $ns" >/dev/null 2>&1
  done
  return 0
}

# port_free PORT: return 0 if nothing listens on PORT. Otherwise explain who
# holds it and how to free it, and return 1.
port_free() {
  local port="$1" holder rc
  holder=$(pgrep -fl "port-forward .* ${port}:" 2>/dev/null | head -n 1)
  if [ -n "$holder" ]; then
    warn "Port $port is already used by a kubectl port-forward: $holder"
    printf '   Stop it with:  pkill -f "port-forward"   (or press Ctrl+C in the terminal that runs it)\n'
    return 1
  fi
  curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$port"
  rc=$?
  # 7 = connection refused (nothing there). Any other result means something answered.
  if [ "$rc" -ne 7 ]; then
    warn "Port $port is already used by another program on your computer."
    printf '   Pick another port / close that program, then run this again.\n'
    return 1
  fi
  return 0
}

# create_showdown_configmap NS: ConfigMap showdown-code (keys app.py, index.html)
# built from apps/api/, so the Cats vs Dogs code is never copied into scenarios.
create_showdown_configmap() {
  local ns="$1" api="$_K8S_LIB_DIR/../../apps/api"
  kubectl create configmap showdown-code -n "$ns" \
    --from-file=app.py="$api/app.py" \
    --from-file=index.html="$api/static/index.html" >/dev/null
}

# pod_reason NS SELECTOR: first Pod's waiting reason, else last terminated
# reason, else phase.
pod_reason() {
  local ns="$1" sel="$2" r
  r=$(kubectl get pods -n "$ns" -l "$sel" -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
  [ -z "$r" ] && r=$(kubectl get pods -n "$ns" -l "$sel" -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)
  [ -z "$r" ] && r=$(kubectl get pods -n "$ns" -l "$sel" -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  printf '%s\n' "$r"
}

# scenario_k8s_cleanup NS...: stop port-forwards, delete namespaces. Never fails.
scenario_k8s_cleanup() {
  local first="$1" id ns
  stop_port_forwards "$@"
  delete_ns "$@"
  for ns in "$@"; do
    kubectl get namespace "$ns" >/dev/null 2>&1 && return 0
  done
  id="k${first#k-}"
  id="${id%%-*}"
  printf '✅ Scenario %s cleaned up\n' "$id"
  return 0
}

# ---- Cluster-level helpers (batch 3) ---------------------------------------

# schedulable_node_count: print how many nodes accept new Pods: no NoSchedule/NoExecute
# taint (PreferNoSchedule does not count) and not cordoned (spec.unschedulable).
schedulable_node_count() {
  local out
  # A failed kubectl (or an empty node list) is an error (return 1, print nothing), never "0".
  out=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" U="}{.spec.unschedulable}{" "}{range .spec.taints[*]}{"|"}{.effect}{"|"}{end}{"\n"}{end}' 2>/dev/null) || return 1
  [ -n "$out" ] || return 1
  printf '%s\n' "$out" | grep -c -v -E ' U=true |\|NoSchedule\||\|NoExecute\|'
  return 0
}

# untaint_all KEY: remove the taint KEY (any value, any effect) from every node.
# Silent and idempotent ("not found" is ignored). Always returns 0.
untaint_all() {
  kubectl taint nodes --all "$1-" >/dev/null 2>&1
  return 0
}

# _ms_available: 0 when the metrics.k8s.io APIService reports Available=True.
_ms_available() {
  [ "$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)" = "True" ]
}

# ensure_metrics_server ID: make `kubectl top` work.
#  - APIService Available: print "metrics-server already present", return 0.
#  - An APIService or Deployment metrics-server exists that is NOT labelled
#    z2h.scenario=<ID>-installed (someone else's, maybe still starting): never touch
#    it; only wait (bounded) for it to become usable.
#  - Otherwise (nothing there, or ours from an interrupted run): apply the manifest.
# The shipped manifest labels every object z2h.scenario=k25-installed; for another ID it
# is rewritten with sed into a temp file, so the label is always <ID>-installed.
# Waits up to 180 s (override: Z2H_MS_WAIT, used by the self-test) until `kubectl top nodes` works. Returns 1 on timeout.
ensure_metrics_server() {
  local id="$1" sel tmp i=0 present=0 ours=0
  sel="z2h.scenario=${id}-installed"
  if _ms_available; then
    printf 'metrics-server already present\n'
    return 0
  fi
  if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1 ||
     kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
    present=1
  fi
  if [ -n "$(kubectl get apiservice,deployment -A -l "$sel" -o name 2>/dev/null)" ]; then
    ours=1
  fi
  if [ "$present" -eq 1 ] && [ "$ours" -eq 0 ]; then
    printf 'metrics-server already present (not installed by us), waiting for it to become ready\n'
  else
    tmp=$(mktemp "${TMPDIR:-/tmp}/z2h-ms.XXXXXX") || return 1
    sed "s/k25-installed/${id}-installed/g" "$_K8S_LIB_DIR/_addons/metrics-server.yaml" >"$tmp"
    kubectl apply -f "$tmp" >/dev/null || { rm -f "$tmp"; return 1; }
    rm -f "$tmp"
  fi
  while [ "$i" -lt "${Z2H_MS_WAIT:-180}" ]; do
    kubectl top nodes >/dev/null 2>&1 && return 0
    sleep 2
    i=$((i + 2))
  done
  warn "metrics-server did not become ready within ${Z2H_MS_WAIT:-180}s. Check: kubectl -n kube-system get pods -l k8s-app=metrics-server"
  return 1
}

# remove_metrics_server_if_ours ID: delete only objects labelled
# z2h.scenario=<ID>-installed (a metrics-server that was already there stays).
# Silent, always returns 0.
remove_metrics_server_if_ours() {
  local sel="z2h.scenario=$1-installed"
  # The APIService first, so `kubectl api-resources` stops complaining at once.
  kubectl delete apiservice -l "$sel" --ignore-not-found >/dev/null 2>&1
  kubectl delete deployment,service,serviceaccount,rolebinding -n kube-system -l "$sel" --ignore-not-found >/dev/null 2>&1
  kubectl delete clusterrolebinding,clusterrole -l "$sel" --ignore-not-found >/dev/null 2>&1
  return 0
}

# ---- "Am I done?" helpers. Read-only: they look, they never change anything. ----

# check_rollouts NS...: every Deployment in these namespaces has all its replicas Ready.
# Prints what is still missing and returns 1 if not.
check_rollouts() {
  local ns name want have bad=0
  for ns in "$@"; do
    while read -r name want have; do
      [ -z "$name" ] && continue
      if [ "${have:-0}" != "$want" ]; then
        warn "Deployment $name has ${have:-0} of $want Pods Ready (namespace $ns)."
        bad=1
      fi
    done < <(kubectl get deployments -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name} {.spec.replicas} {.status.readyReplicas}{"\n"}{end}' 2>/dev/null)
  done
  return "$bad"
}

# check_visitor NS: the visitor's last three lines are all ✅.
check_visitor() {
  local ns="$1" lines n
  lines=$(kubectl logs visitor -n "$ns" --tail=3 2>/dev/null)
  n=$(printf '%s\n' "$lines" | grep -c '^✅')
  [ "$n" -ge 3 ] && return 0
  warn "The visitor is not all ✅ yet. Its latest lines:"
  printf '%s\n' "$lines" | sed 's/^/     /'
  return 1
}

# ---- Monitoring helpers (scenarios K46 to K48 use Prometheus from lab K19) ----

# need_monitoring: stop early, with one friendly line, unless Prometheus is running.
need_monitoring() {
  if ! kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -q Running; then
    die "Prometheus isn't running. This scenario watches the cluster through it. Install it once (about 5 minutes): ./scripts/install-monitoring.sh"
  fi
}

# urlencode STRING: percent-encode a PromQL expression for a URL (pure bash).
urlencode() {
  local s="$1" i c out=""
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

# prom_query EXPR: raw JSON from Prometheus' query API, reached through the API server
# (no port-forward needed).
prom_query() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/api/v1/query?query=$(urlencode "$1")" 2>/dev/null
}

# prom_has EXPR: success if the query returns at least one series.
prom_has() {
  prom_query "$1" | grep -q '"result":\[{'
}
