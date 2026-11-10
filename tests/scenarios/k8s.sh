#!/usr/bin/env bash
# Usage: ./tests/scenarios/k8s.sh [NN ...]   (no args = all present scenarios)
# For each scenario NN: sources tests/scenarios/k8s/NN.sh (defines NAMESPACES,
# broken() and fixed()) and runs two full break/fix cycles. Only runs against the
# throwaway cluster: export KUBECONFIG=$HOME/.kube/z2h-test.config
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO" || exit 1
# Safety: this harness only ever talks to the throwaway cluster, so refuse any other kubeconfig.
# Dry run on a playground or another throwaway cluster you own: set Z2H_DRY_RUN_CONTEXT to that
# cluster's exact context name (kubectl config current-context). Nothing else is accepted.
if [ -z "${Z2H_DRY_RUN_CONTEXT:-}" ] && [ "${KUBECONFIG:-}" != "$HOME/.kube/z2h-test.config" ]; then
  printf 'Refusing to run: KUBECONFIG is "%s", not the throwaway cluster'"'"'s (context kind-z2h-test).\n' "${KUBECONFIG:-}" >&2
  printf 'Create and use the test cluster:\n  tests/scenarios/k8s-cluster.sh up\n  export KUBECONFIG=$HOME/.kube/z2h-test.config\n' >&2
  exit 1
fi
# shellcheck source=k8s-lib.sh
source "$REPO/tests/scenarios/k8s-lib.sh"

require_test_cluster || exit 1

if [ "$#" -gt 0 ]; then
  NUMS="$*"
else
  NUMS=""
  for d in "$REPO"/kubernetes/scenarios/[0-9][0-9]-*/; do
    [ -d "$d" ] || continue
    b="$(basename "$d")"
    NUMS="$NUMS ${b%%-*}"
  done
fi

if [ -z "${NUMS# }" ]; then
  printf 'No scenarios found under kubernetes/scenarios/ (and none given on the command line).\n' >&2
  exit 1
fi

PASSED=""; FAILED=""
for nn in $NUMS; do
  printf '== Scenario %s\n' "$nn"
  dir=""
  for d in "$REPO"/kubernetes/scenarios/"$nn"-*/; do [ -d "$d" ] && dir="${d%/}"; done
  spec="$REPO/tests/scenarios/k8s/$nn.sh"
  if [ -z "$dir" ]; then printf '  folder kubernetes/scenarios/%s-* not found\n' "$nn"; FAILED="$FAILED $nn"; continue; fi
  if [ ! -f "$spec" ]; then printf '  missing %s\n' "$spec"; FAILED="$FAILED $nn"; continue; fi
  if (
    NAMESPACES=""
    # shellcheck source=/dev/null
    source "$spec"
    # shellcheck disable=SC2086
    run_cycle_k8s "$dir" "k$nn" $NAMESPACES
  ); then
    PASSED="$PASSED $nn"
  else
    FAILED="$FAILED $nn"
  fi
done

printf '\n== Summary\n'
for nn in $PASSED; do printf '✅ %s\n' "$nn"; done
for nn in $FAILED; do printf '❌ %s\n' "$nn"; done
[ -z "$FAILED" ]
