#!/usr/bin/env bash
# Throwaway kind cluster for the Kubernetes scenario harness.
# Usage: tests/scenarios/k8s-cluster.sh up [--single] | down | status
# Only ever touches the cluster named z2h-test and ~/.kube/z2h-test.config.
# It never reads or writes ~/.kube/config and never uses extraPortMappings.
set -u

NAME="z2h-test"
KCFG="$HOME/.kube/z2h-test.config"

cluster_exists() { kind get clusters 2>/dev/null | grep -qx "$NAME"; }

cmd_up() {
  local single=0
  [ "${1:-}" = "--single" ] && single=1
  command -v kind >/dev/null 2>&1 || { echo "kind isn't installed." >&2; return 1; }
  if cluster_exists; then
    echo "Cluster $NAME already exists (run '$0 down' first to recreate it)."
  else
    local cfg
    cfg="$(mktemp)"
    {
      printf 'kind: Cluster\napiVersion: kind.x-k8s.io/v1alpha4\nnodes:\n  - role: control-plane\n'
      if [ "$single" -eq 0 ]; then
        printf '  - role: worker\n  - role: worker\n'
      fi
    } >"$cfg"
    mkdir -p "$HOME/.kube"
    kind create cluster --name "$NAME" --kubeconfig "$KCFG" --config "$cfg" --wait 120s || { rm -f "$cfg"; return 1; }
    rm -f "$cfg"
    # --wait covers the control plane; make sure every worker is Ready (kindnet up) too.
    KUBECONFIG="$KCFG" kubectl wait --for=condition=Ready node --all --timeout=120s || return 1
  fi
  echo
  echo "Use it with:"
  echo "  export KUBECONFIG=$KCFG"
}

cmd_down() {
  if cluster_exists; then
    kind delete cluster --name "$NAME" --kubeconfig "$KCFG"
  else
    echo "Cluster $NAME does not exist."
  fi
  return 0
}

cmd_status() {
  if cluster_exists; then
    echo "Cluster $NAME exists."
    KUBECONFIG="$KCFG" kubectl get nodes 2>&1
    echo "export KUBECONFIG=$KCFG"
  else
    echo "Cluster $NAME does not exist. Create it with: $0 up"
  fi
  return 0
}

case "${1:-}" in
  up) shift; cmd_up "$@" ;;
  down) cmd_down ;;
  status) cmd_status ;;
  *) echo "Usage: $0 up [--single] | down | status" >&2; exit 2 ;;
esac
