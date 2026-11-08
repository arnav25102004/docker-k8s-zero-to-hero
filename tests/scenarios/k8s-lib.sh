#!/usr/bin/env bash
# Test helpers for the Kubernetes scenario harness. Sourced by k8s.sh and the
# self-test. Builds on lib.sh (asserts, _step, _check).
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# require_test_cluster: refuse to run against anything but the throwaway kind cluster.
require_test_cluster() {
  local ctx
  ctx=$(kubectl config current-context 2>/dev/null)
  if [ "$ctx" != "kind-z2h-test" ]; then
    printf 'Refusing to run: current kubectl context is "%s", not "kind-z2h-test".\n' "${ctx:-none}" >&2
    printf 'Create the test cluster and use it:\n  tests/scenarios/k8s-cluster.sh up\n  export KUBECONFIG=$HOME/.kube/z2h-test.config\n' >&2
    return 1
  fi
}

# in_cluster_http NS URL: HTTP status code seen from inside the cluster, or 000.
in_cluster_http() {
  local ns="$1" url="$2" out code
  out=$(kubectl run "ihttp-$$-$RANDOM" -n "$ns" --rm -i --restart=Never --quiet \
    --image=curlimages/curl:8.11.1 --command -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null)
  code=$(printf '%s' "$out" | grep -o '^[0-9][0-9][0-9]' | head -n 1)
  printf '%s\n' "${code:-000}"
}

# wait_ready NS SELECTOR SECONDS: wait until the selected Pods are Ready.
wait_ready() {
  local i=0
  # kubectl wait -l errors at once when no Pod matches yet: poll for existence first.
  while [ "$i" -lt "$3" ] && [ -z "$(kubectl get pods -n "$1" -l "$2" -o name 2>/dev/null)" ]; do
    sleep 1
    i=$((i + 1))
  done
  kubectl wait --for=condition=Ready pod -l "$2" -n "$1" --timeout="${3}s" >/dev/null 2>&1
}

# nothing_left_k8s ID NS...: no namespace, no port-forward, no labelled cluster-scoped object.
nothing_left_k8s() {
  local id="$1" ns left
  shift
  for ns in "$@"; do
    kubectl get namespace "$ns" >/dev/null 2>&1 && return 1
    pgrep -f "port-forward -n $ns" >/dev/null 2>&1 && return 1
  done
  left=$(kubectl get clusterroles,clusterrolebindings,persistentvolumes -l "z2h.scenario=$id" -o name 2>/dev/null)
  [ -z "$left" ]
}

# run_cycle_k8s DIR ID NS...: cleanup -> break -> broken -> fix -> fixed -> cleanup
# -> nothing left. Twice. broken() and fixed() must be defined by the caller.
run_cycle_k8s() {
  local dir="$1" id="$2" n
  shift 2
  for n in 1 2; do
    printf '  -- cycle %s/2\n' "$n"
    _step cleanup "$n" "$dir/cleanup.sh" || return 1
    _step break.sh "$n" "$dir/break/break.sh" || return 1
    _check broken "$n" broken || return 1
    _step fix.sh "$n" "$dir/fix/fix.sh" || return 1
    _check fixed "$n" fixed || return 1
    _step "final cleanup" "$n" "$dir/cleanup.sh" || return 1
    nothing_left_k8s "$id" "$@" || { printf '  FAILED at step: nothing-left check (cycle %s)\n' "$n"; return 1; }
  done
  return 0
}
