#!/usr/bin/env bash
# Usage: ./tests/labs/validate-labs.sh
# Does every manifest in the Kubernetes labs (K02 to K18 and stack/) still get accepted by a real
# cluster's API server? It asks the server to check each file with a server-side dry-run, so no
# Pods are started and no images are pulled. The only things it creates are the labs' own
# namespaces (to make the checks realistic), and it removes them again at the end.
# Catches: removed API versions, typos, fields a newer Kubernetes no longer accepts, Pod Security
# rules that reject a lab's own Pod.
# Only runs against the throwaway cluster (same safety rule as the scenario harness):
#   export KUBECONFIG=$HOME/.kube/z2h-test.config
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO" || exit 1
if [ -z "${Z2H_DRY_RUN_CONTEXT:-}" ] && [ "${KUBECONFIG:-}" != "$HOME/.kube/z2h-test.config" ]; then
  printf 'Refusing to run: KUBECONFIG is "%s", not the throwaway cluster'"'"'s.\n' "${KUBECONFIG:-}" >&2
  printf 'Use the test cluster:\n  tests/scenarios/k8s-cluster.sh up\n  export KUBECONFIG=$HOME/.kube/z2h-test.config\n' >&2
  exit 1
fi
kubectl get --raw /readyz >/dev/null 2>&1 || { echo "Can't reach the cluster." >&2; exit 1; }
TMP="$(mktemp -d)"
CREATED=""
cleanup() {
  local ns
  for ns in $CREATED; do kubectl delete namespace "$ns" --wait=false >/dev/null 2>&1; done
  rm -rf "$TMP"
}
trap cleanup EXIT

# 1. Create each namespace the lab files define (with its real labels), if it is not there already.
#    Pure shell: split every file at "---" and keep the documents whose kind is Namespace.
: > "$TMP/namespaces.yaml"
for f in $(find kubernetes -name '*.yaml' -not -path 'kubernetes/scenarios/*' | sort); do
  awk '
    function flush() { if (d ~ /(^|\n)kind: Namespace[ \t]*(\n|$)/) printf "---\n%s", d; d = "" }
    /^---[ \t]*$/ { flush(); next }
    { d = d $0 "\n" }
    END { flush() }
  ' "$f" >> "$TMP/namespaces.yaml"
done
for ns in $(kubectl create --dry-run=client -f "$TMP/namespaces.yaml" -o name 2>/dev/null | sed 's#^namespace/##' | sort -u); do
  kubectl get namespace "$ns" >/dev/null 2>&1 || CREATED="$CREATED $ns"
done
kubectl apply -f "$TMP/namespaces.yaml" >/dev/null 2>&1 || { echo "Could not create the lab namespaces." >&2; exit 1; }

HAVE_GATEWAY=no
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 && HAVE_GATEWAY=yes
HAVE_PROM=no
kubectl get crd prometheusrules.monitoring.coreos.com >/dev/null 2>&1 && HAVE_PROM=yes

PASS=0; FAIL=0; SKIP=0
check() { # LABEL KUBECTL-ARGS...   (last two args are "-f FILE" or "-k DIR")
  local label="$1" out
  shift
  if out=$(kubectl apply --dry-run=server "$@" 2>&1); then
    printf '  ok: %s\n' "$label"; PASS=$((PASS + 1))
  # A file that creates a ServiceAccount and then a Pod that uses it: a dry run does not keep the
  # account, so the server cannot find it. Check the file's shape instead of failing it.
  elif printf '%s' "$out" | grep -q 'serviceaccount .* not found' && kubectl apply --dry-run=client "$@" >/dev/null 2>&1; then
    printf '  ok: %s (the Pod uses a ServiceAccount made in the same file, so only its shape was checked)\n' "$label"; PASS=$((PASS + 1))
  else
    printf '  FAIL: %s\n' "$label"; printf '%s\n' "$out" | tail -n 4 | sed 's/^/        | /'; FAIL=$((FAIL + 1))
  fi
}

# A file whose first comment says it "will be REJECTED" is supposed to be refused by the cluster.
check_refused() { # LABEL FILE
  local out
  if out=$(kubectl apply --dry-run=server -f "$2" 2>&1); then
    printf '  FAIL: %s was accepted, but the lab says it must be refused\n' "$1"; FAIL=$((FAIL + 1))
  elif printf '%s' "$out" | grep -q 'violates PodSecurity'; then
    printf '  ok: %s (refused by Pod Security, as the lab intends)\n' "$1"; PASS=$((PASS + 1))
  else
    printf '  FAIL: %s was refused for another reason\n' "$1"; printf '%s\n' "$out" | tail -n 3 | sed 's/^/        | /'; FAIL=$((FAIL + 1))
  fi
}

# 2. Every manifest, lab by lab (kustomize folders as one unit).
for dir in kubernetes/[0-9][0-9]-*/ kubernetes/stack/ kubernetes/projects/project-1-canteen-rush/k8s/ kubernetes/projects/project-2-canteen-helm/k8s-raw/; do
  dir="${dir%/}"
  [ -d "$dir" ] || continue
  printf '== %s\n' "${dir#kubernetes/}"
  for f in "$dir"/*.yaml; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in kustomization.yaml) continue ;; esac
    if grep -q 'gateway.networking.k8s.io' "$f" && [ "$HAVE_GATEWAY" = no ]; then
      printf '  skip: %s (needs the Gateway API CRDs from lab K12)\n' "$(basename "$f")"; SKIP=$((SKIP + 1)); continue
    fi
    if grep -q 'monitoring.coreos.com' "$f" && [ "$HAVE_PROM" = no ]; then
      printf '  skip: %s (needs the Prometheus CRDs from lab K19)\n' "$(basename "$f")"; SKIP=$((SKIP + 1)); continue
    fi
    if head -n 3 "$f" | grep -q 'REJECTED'; then
      check_refused "$(basename "$f")" "$f"
    else
      check "$(basename "$f")" -f "$f"
    fi
  done
  if [ -f "$dir/manifests/kustomization.yaml" ]; then
    if grep -rq 'gateway.networking.k8s.io' "$dir/manifests" "$dir/gateway.yaml" 2>/dev/null && [ "$HAVE_GATEWAY" = no ]; then
      printf '  skip: manifests/ (needs the Gateway API CRDs from lab K12)\n'; SKIP=$((SKIP + 1))
    else
      check "manifests/ (kustomize)" -k "$dir/manifests"
    fi
  fi
done

# 3. The Helm chart of Project 2: lint it, render it with each values file, and let the server check the result.
if command -v helm >/dev/null 2>&1 && [ -d kubernetes/projects/project-2-canteen-helm/chart/canteen ]; then
  printf '== projects/project-2-canteen-helm/chart\n'
  CHART=kubernetes/projects/project-2-canteen-helm/chart/canteen
  if helm lint "$CHART" >/dev/null 2>&1; then printf '  ok: helm lint\n'; PASS=$((PASS + 1)); else printf '  FAIL: helm lint\n'; FAIL=$((FAIL + 1)); fi
  for vf in "" "-f $CHART/values-dev.yaml" "-f $CHART/values-prod.yaml"; do
    label="render ${vf:+with ${vf##*/}}"; label="${label:-render with defaults}"
    # shellcheck disable=SC2086
    if helm template canteen "$CHART" $vf 2>/dev/null | kubectl apply --dry-run=server -f - >/dev/null 2>"$TMP/chart.err"; then
      printf '  ok: %s\n' "$label"; PASS=$((PASS + 1))
    else
      printf '  FAIL: %s\n' "$label"; tail -n 3 "$TMP/chart.err" | sed 's/^/        | /'; FAIL=$((FAIL + 1))
    fi
  done
fi

printf '\n== Summary: %s ok, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$SKIP" -gt 0 ] && printf 'Skipped files need the Gateway API CRDs (lab K12, step 1) or the Prometheus CRDs (./scripts/install-monitoring.sh). Install them and run again to cover them.\n'
[ "$FAIL" -eq 0 ]
