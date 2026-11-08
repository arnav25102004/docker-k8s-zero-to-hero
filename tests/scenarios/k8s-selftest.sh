#!/usr/bin/env bash
# Self-test for kubernetes/scenarios/_lib.sh and the k8s harness helpers.
# Needs the throwaway cluster:  tests/scenarios/k8s-cluster.sh up
# Usage: bash tests/scenarios/k8s-selftest.sh
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO/kubernetes/scenarios/_lib.sh"
cd "$REPO" || exit 1

# Safety: this file only ever talks to the throwaway cluster (never the owner's others).
export KUBECONFIG="$HOME/.kube/z2h-test.config"

PASS=0; FAIL=0
FAILED_NAMES=""
PF_PID=""
TMPD="$(mktemp -d)"

cleanup_all() {
  [ -n "$PF_PID" ] && kill "$PF_PID" >/dev/null 2>&1
  pkill -f "port-forward -n k-98-selftest" >/dev/null 2>&1
  for n in k-99-selftest k-98-selftest k-97-selftest; do
    kubectl delete namespace "$n" --ignore-not-found --wait=false >/dev/null 2>&1
  done
  rm -rf "$TMPD"
}
trap cleanup_all EXIT

check() { # check MSG CMD... (passes when CMD succeeds)
  local msg="$1"
  shift
  if "$@"; then printf '    ok: %s\n' "$msg"; else printf '    FAIL: %s\n' "$msg"; return 1; fi
}
rc_is() { [ "$1" -eq "$2" ]; }
has() { printf '%s' "$1" | grep -q -- "$2"; }
no_ns() { ! kubectl get namespace "$1" >/dev/null 2>&1; }
no_pf() { ! pgrep -f "port-forward -n $1" >/dev/null 2>&1; }

run_test() {
  local name="$1" out rc
  printf '== %s\n' "$name"
  out=$("$name" 2>&1); rc=$?
  printf '%s\n' "$out"
  if [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1)); printf '✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES="$FAILED_NAMES $name"; printf '❌ %s\n' "$name"
  fi
}

test_no_cluster_message() {
  local out rc f=0
  out=$(KUBECONFIG=/nonexistent bash -c "source '$LIB'; need_cluster" 2>&1); rc=$?
  check "exits 1" rc_is "$rc" 1 || f=1
  check "friendly message" has "$out" "Can't reach a Kubernetes cluster" || f=1
  return $f
}

test_refuses_foreign_context() {
  local out rc f=0 kc="$TMPD/foreign.config"
  cat >"$kc" <<'YAML'
apiVersion: v1
kind: Config
current-context: not-the-test-cluster
clusters:
- name: nowhere
  cluster:
    server: https://127.0.0.1:1
contexts:
- name: not-the-test-cluster
  context:
    cluster: nowhere
    user: nobody
users:
- name: nobody
  user: {}
YAML
  out=$(KUBECONFIG="$kc" bash tests/scenarios/k8s.sh 01 2>&1); rc=$?
  check "exits non-zero" [ "$rc" -ne 0 ] || f=1
  check "names kind-z2h-test" has "$out" "kind-z2h-test" || f=1
  return $f
}

test_cleanup_waits_for_namespace() {
  local f=0
  bash -c "source '$LIB'; fresh_ns k-99-selftest" >/dev/null 2>&1
  kubectl run -n k-99-selftest bb --image=busybox:1.36 --restart=Never -- sleep 3600 >/dev/null 2>&1
  check "label set" has "$(kubectl get ns k-99-selftest --show-labels 2>&1)" "z2h.scenario=k99" || f=1
  bash -c "source '$LIB'; delete_ns k-99-selftest" >/dev/null 2>&1
  check "namespace gone right after delete_ns" no_ns k-99-selftest || f=1
  check "fresh_ns succeeds at once" bash -c "source '$LIB'; fresh_ns k-99-selftest >/dev/null 2>&1" || f=1
  bash -c "source '$LIB'; delete_ns k-99-selftest" >/dev/null 2>&1
  return $f
}

test_cleanup_stops_port_forward() {
  local f=0 out rc i
  bash -c "source '$LIB'; fresh_ns k-98-selftest" >/dev/null 2>&1
  kubectl create deployment whoami -n k-98-selftest --image=traefik/whoami:v1.10.3 >/dev/null 2>&1
  kubectl expose deployment whoami -n k-98-selftest --port=80 >/dev/null 2>&1
  kubectl rollout status deployment/whoami -n k-98-selftest --timeout=180s >/dev/null 2>&1
  kubectl port-forward -n k-98-selftest --address 127.0.0.1 svc/whoami 9298:80 >/dev/null 2>&1 &
  PF_PID=$!
  i=0
  while [ "$i" -lt 30 ] && ! curl -s --max-time 2 localhost:9298 >/dev/null 2>&1; do sleep 1; i=$((i + 1)); done
  check "port-forward answers" curl -s -o /dev/null --max-time 2 localhost:9298 || f=1
  out=$(bash -c "source '$LIB'; port_free 9298" 2>&1); rc=$?
  check "port_free returns 1" rc_is "$rc" 1 || f=1
  check "port_free names port-forward" has "$out" "port-forward" || f=1
  out=$(bash -c "source '$LIB'; scenario_k8s_cleanup k-98-selftest" 2>&1); rc=$?
  check "cleanup returns 0" rc_is "$rc" 0 || f=1
  check "cleanup prints done line" has "$out" "Scenario k98 cleaned up" || f=1
  sleep 1
  check "curl to 9298 fails" bash -c '! curl -s --max-time 2 localhost:9298 >/dev/null' || f=1
  check "no port-forward process left" no_pf k-98-selftest || f=1
  check "namespace gone" no_ns k-98-selftest || f=1
  PF_PID=""
  return $f
}

test_showdown_configmap() {
  local f=0 a b
  bash -c "source '$LIB'; fresh_ns k-97-selftest; create_showdown_configmap k-97-selftest" >/dev/null 2>&1 || f=1
  a=$(kubectl get cm showdown-code -n k-97-selftest -o jsonpath='{.data.app\.py}' | wc -c | tr -d ' ')
  b=$(kubectl get cm showdown-code -n k-97-selftest -o jsonpath='{.data.index\.html}' | wc -c | tr -d ' ')
  check "app.py size matches" rc_is "$a" "$(wc -c <apps/api/app.py | tr -d ' ')" || f=1
  check "index.html size matches" rc_is "$b" "$(wc -c <apps/api/static/index.html | tr -d ' ')" || f=1
  bash -c "source '$LIB'; delete_ns k-97-selftest" >/dev/null 2>&1
  return $f
}

test_pod_reason() {
  local f=0 r
  bash -c "source '$LIB'; fresh_ns k-97-selftest" >/dev/null 2>&1
  kubectl run -n k-97-selftest bad --image=busybox:1.36 --restart=Never --labels=app=bad -- sh -c 'exit 3' >/dev/null 2>&1
  sleep 8
  r=$(bash -c "source '$LIB'; pod_reason k-97-selftest app=bad" 2>&1)
  check "reason is Error or Failed (got $r)" bash -c "[ \"$r\" = Error ] || [ \"$r\" = Failed ]" || f=1
  bash -c "source '$LIB'; delete_ns k-97-selftest" >/dev/null 2>&1
  return $f
}

test_lib_sourcing_is_quiet() {
  local out
  out=$(bash -c "source '$LIB'" 2>&1)
  check "no output when sourced" [ -z "$out" ]
}

for t in test_no_cluster_message test_refuses_foreign_context test_lib_sourcing_is_quiet \
         test_cleanup_waits_for_namespace test_cleanup_stops_port_forward \
         test_showdown_configmap test_pod_reason; do
  run_test "$t"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || { printf 'Failed:%s\n' "$FAILED_NAMES"; exit 1; }
