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
  done
  return 0
}

# fresh_ns NS...: delete (and wait for) then create each namespace, labelled
# z2h.scenario=<kNN> taken from the k-NN- prefix.
fresh_ns() {
  local ns id
  for ns in "$@"; do
    delete_ns "$ns"
    kubectl create namespace "$ns" >/dev/null || return 1
    id="k${ns#k-}"
    id="${id%%-*}"
    kubectl label namespace "$ns" "z2h.scenario=$id" --overwrite >/dev/null || return 1
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
  local first="$1" id
  stop_port_forwards "$@"
  delete_ns "$@"
  id="k${first#k-}"
  id="${id%%-*}"
  printf '✅ Scenario %s cleaned up\n' "$id"
  return 0
}
