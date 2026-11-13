#!/usr/bin/env bash
# Usage: ./tests/scenarios/k8s.sh [S2.3 | 2 | 08 ...]   (no args = all scenarios; a section digit runs the whole section)
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
  printf 'Dry run on a playground or another throwaway cluster instead (see kubernetes/scenarios/README.md, "Playground dry-run checklist"):\n  export Z2H_DRY_RUN_CONTEXT="$(kubectl config current-context)"\n' >&2
  exit 1
fi
# shellcheck source=k8s-lib.sh
source "$REPO/tests/scenarios/k8s-lib.sh"

require_test_cluster || exit 1

# A stop in the middle of an earlier run (Ctrl+C, a crash) can leave K16's node taint behind,
# and then every scenario's Pods sit Pending. This cluster is the throwaway one, so clear it.
kubectl taint nodes --all z2h-vip- >/dev/null 2>&1 || true

INDEX="$REPO/kubernetes/scenarios/index.tsv"
[ -f "$INDEX" ] || { printf 'Missing %s\n' "$INDEX" >&2; exit 1; }

# Accepts: S2.3, 2.3, S5.x1 (one scenario), 2 or S2 (a whole section), the old two-digit number (08),
# or nothing (everything). Resolves each to a row of index.tsv: id, legacy, path.
RUN=""
if [ "$#" -eq 0 ]; then
  RUN="$(awk -F'\t' 'NR>1 {print $2}' "$INDEX")"
else
  for a in "$@"; do
    k="$(printf '%s' "$a" | sed 's/^[sS]//')"
    m="$(awk -F'\t' -v k="$k" 'NR>1 { id=substr($1,2); if (id==k || $2==k || index(id, k ".")==1) print $2 }' "$INDEX")"
    if [ -z "$m" ]; then printf 'Unknown scenario: %s (try S2.3, 2, or 08)\n' "$a" >&2; exit 1; fi
    RUN="$RUN
$m"
  done
fi

PASSED=""; FAILED=""
for nn in $RUN; do
  row="$(awk -F'\t' -v n="$nn" '$2==n' "$INDEX")"
  sid="$(printf '%s' "$row" | cut -f1)"; rel="$(printf '%s' "$row" | cut -f3)"
  printf '== Scenario %s (old number %s)\n' "$sid" "$nn"
  dir="$REPO/kubernetes/scenarios/$rel"
  spec="$REPO/tests/scenarios/k8s/$nn.sh"
  if [ ! -d "$dir" ]; then printf '  folder %s not found\n' "$dir"; FAILED="$FAILED $sid"; continue; fi
  if [ ! -f "$spec" ]; then printf '  missing %s\n' "$spec"; FAILED="$FAILED $sid"; continue; fi
  if (
    NAMESPACES=""
    # shellcheck source=/dev/null
    source "$spec"
    # shellcheck disable=SC2086
    run_cycle_k8s "$dir" "k$nn" $NAMESPACES
  ); then
    PASSED="$PASSED $sid"
  else
    FAILED="$FAILED $sid"
  fi
done

printf '\n== Summary\n'
for nn in $PASSED; do printf '✅ %s\n' "$nn"; done
for nn in $FAILED; do printf '❌ %s\n' "$nn"; done
[ -z "$FAILED" ]
