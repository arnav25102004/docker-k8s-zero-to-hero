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

# shellcheck source=k8s-lib.sh
source "$REPO/tests/scenarios/k8s-lib.sh"
require_test_cluster || exit 1

PASS=0; FAIL=0
FAILED_NAMES=""
PF_PID=""
TMPD="$(mktemp -d)"

cleanup_all() {
  [ -n "$PF_PID" ] && kill "$PF_PID" >/dev/null 2>&1
  pkill -f "port-forward -n k-98-selftest" >/dev/null 2>&1
  for n in k-99-selftest k-98-selftest k-97-selftest k-96-selftest k-95-selftest k-94-selftest; do
    kubectl delete namespace "$n" --ignore-not-found --wait=false >/dev/null 2>&1
  done
  # Revert cluster-level test changes too (taints, labels, metrics-server, dummies).
  ( # shellcheck source=/dev/null
    source "$LIB" >/dev/null 2>&1
    untaint_all z2h-selftest; untaint_all z2h-x; untaint_all z2h-vip
    kubectl label nodes --all z2h-lbl- >/dev/null 2>&1
    remove_metrics_server_if_ours k99
    kubectl delete configmap z2h-selftest-dummy -n kube-system --ignore-not-found >/dev/null 2>&1
    kubectl delete deployment metrics-server -n kube-system -l z2h-selftest=dummy --ignore-not-found >/dev/null 2>&1
  ) 2>/dev/null
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
fails() { ! "$@"; }
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
  out=$(KUBECONFIG="$kc" bash -c "source '$REPO/tests/scenarios/k8s-lib.sh'; require_test_cluster" 2>&1); rc=$?
  check "exits non-zero" [ "$rc" -ne 0 ] || f=1
  check "names kind-z2h-test" has "$out" "kind-z2h-test" || f=1
  out=$(KUBECONFIG="$kc" bash tests/scenarios/k8s.sh 01 2>&1); rc=$?
  check "k8s.sh refuses a foreign kubeconfig" [ "$rc" -ne 0 ] || f=1
  check "k8s.sh names kind-z2h-test" has "$out" "kind-z2h-test" || f=1
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
  kubectl create deployment whoami -n k-98-selftest --image=traefik/whoami:v1.10.4 >/dev/null 2>&1
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
  local f=0 r i
  bash -c "source '$LIB'; fresh_ns k-97-selftest" >/dev/null 2>&1
  kubectl run -n k-97-selftest bad --image=busybox:1.36 --restart=Never --labels=app=bad -- sh -c 'exit 3' >/dev/null 2>&1
  i=0
  # Wait for the Pod PHASE to be Failed (the container's terminated state shows up a moment
  # earlier, while the phase can still read Pending when the image is already on the node).
  while [ "$i" -lt 60 ] && [ "$(kubectl get pod bad -n k-97-selftest -o jsonpath='{.status.phase}' 2>/dev/null)" != "Failed" ]; do
    sleep 1; i=$((i + 1))
  done
  r=$(bash -c "source '$LIB'; pod_reason k-97-selftest app=bad" 2>&1)
  check "reason is Error or Failed (got $r)" bash -c "[ \"$r\" = Error ] || [ \"$r\" = Failed ]" || f=1
  bash -c "source '$LIB'; delete_ns k-97-selftest" >/dev/null 2>&1
  return $f
}

test_fresh_ns_has_default_sa() {
  local f=0
  bash -c "source '$LIB'; fresh_ns k-95-selftest" >/dev/null 2>&1
  check "default ServiceAccount exists right after fresh_ns" kubectl get sa default -n k-95-selftest || f=1
  bash -c "source '$LIB'; delete_ns k-95-selftest" >/dev/null 2>&1
  return $f
}

# Builds a dummy scenario in a temp dir. $1 = expected first assert value (ok/bad).
make_dummy_scenario() { # DIR
  local d="$1"
  mkdir -p "$d/break" "$d/fix"
  cat >"$d/cleanup.sh" <<SH
#!/usr/bin/env bash
source '$LIB'
scenario_k8s_cleanup k-96-selftest
SH
  cat >"$d/break/break.sh" <<SH
#!/usr/bin/env bash
source '$LIB'
fresh_ns k-96-selftest
kubectl run -n k-96-selftest bb --image=busybox:1.36 --restart=Never -- sleep 3600
SH
  cat >"$d/fix/fix.sh" <<SH
#!/usr/bin/env bash
kubectl label pod bb -n k-96-selftest fixed=yes
SH
}

run_dummy_cycle() { # DIR BROKEN_EXPECT -> runs run_cycle_k8s in a subshell
  (
    # shellcheck source=/dev/null
    source "$REPO/tests/scenarios/k8s-lib.sh"
    BROKEN_EXPECT="$2"
    broken() { assert_eq "$(kubectl get pod bb -n k-96-selftest -o jsonpath='{.metadata.labels.fixed}')" "$BROKEN_EXPECT" "pod not fixed yet"; }
    fixed() { assert_eq "$(kubectl get pod bb -n k-96-selftest -o jsonpath='{.metadata.labels.fixed}')" "yes" "pod fixed"; }
    run_cycle_k8s "$1" k96 k-96-selftest
  )
}

test_run_cycle_k8s_happy_path() {
  local f=0 d="$TMPD/dummy-ok" rc
  make_dummy_scenario "$d"
  run_dummy_cycle "$d" "" >"$TMPD/ok.out" 2>&1; rc=$?
  cat "$TMPD/ok.out"
  check "run_cycle_k8s returns 0 on success" rc_is "$rc" 0 || f=1
  return $f
}

test_run_cycle_k8s_failing_assert() {
  local f=0 d="$TMPD/dummy-bad" rc out
  make_dummy_scenario "$d"
  out=$(run_dummy_cycle "$d" "WRONG" 2>&1); rc=$?
  printf '%s\n' "$out"
  check "run_cycle_k8s returns 1 on failing assert" rc_is "$rc" 1 || f=1
  check "reports the failed step" has "$out" "FAILED at step: broken" || f=1
  bash "$d/cleanup.sh" >/dev/null 2>&1
  return $f
}

test_lib_sourcing_is_quiet() {
  local out
  out=$(bash -c "source '$LIB'" 2>&1)
  check "no output when sourced" [ -z "$out" ]
}

test_untaint_all_is_idempotent() {
  local f=0 n left
  for n in $(kubectl get nodes -o name); do
    kubectl taint nodes "${n#node/}" z2h-selftest=yes:NoSchedule --overwrite >/dev/null 2>&1
  done
  left=$(kubectl get nodes -o jsonpath='{range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}' | grep -c '^z2h-selftest$')
  check "setup: every node is tainted (found $left)" [ "$left" -gt 0 ] || f=1
  bash -c "source '$LIB'; untaint_all z2h-selftest" >/dev/null 2>&1; check "first untaint_all returns 0" rc_is "$?" 0 || f=1
  bash -c "source '$LIB'; untaint_all z2h-selftest" >/dev/null 2>&1; check "second untaint_all returns 0" rc_is "$?" 0 || f=1
  left=$(kubectl get nodes -o jsonpath='{range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}' | grep -c '^z2h-selftest$')
  check "no node has the taint (found $left)" rc_is "$left" 0 || f=1
  # Mixed case: only one node tainted.
  kubectl taint nodes "$(kubectl get nodes -o name | tail -n 1 | sed 's#^node/##')" z2h-selftest=yes:NoExecute --overwrite >/dev/null 2>&1
  bash -c "source '$LIB'; untaint_all z2h-selftest" >/dev/null 2>&1; check "untaint_all with one tainted node returns 0" rc_is "$?" 0 || f=1
  left=$(kubectl get nodes -o jsonpath='{range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}' | grep -c '^z2h-selftest$')
  check "mixed case: none left (found $left)" rc_is "$left" 0 || f=1
  return $f
}

# Independent count: JSON + python, exact effect match, honouring cordon.
independent_schedulable() {
  kubectl get nodes -o json | python3 -I -c '
import json,sys
n=0
for i in json.load(sys.stdin)["items"]:
    sp=i["spec"]
    bad=sp.get("unschedulable") or any(t["effect"] in ("NoSchedule","NoExecute") for t in sp.get("taints",[]))
    n+=0 if bad else 1
print(n)'
}

test_schedulable_node_count() {
  local f=0 got want node
  node=$(kubectl get nodes -o name | tail -n 1 | sed 's#^node/##')
  got=$(bash -c "source '$LIB'; schedulable_node_count" 2>&1); want=$(independent_schedulable)
  check "count $got equals independent count $want" rc_is "$got" "$want" || f=1
  kubectl taint nodes "$node" z2h-selftest=yes:NoExecute --overwrite >/dev/null 2>&1
  got=$(bash -c "source '$LIB'; schedulable_node_count" 2>&1)
  check "a NoExecute taint lowers the count ($got = $((want - 1)))" rc_is "$got" "$((want - 1))" || f=1
  kubectl taint nodes "$node" z2h-selftest=yes:PreferNoSchedule --overwrite >/dev/null 2>&1
  kubectl taint nodes "$node" z2h-selftest=yes:NoExecute- >/dev/null 2>&1
  got=$(bash -c "source '$LIB'; schedulable_node_count" 2>&1)
  check "PreferNoSchedule does not lower the count ($got = $want)" rc_is "$got" "$want" || f=1
  bash -c "source '$LIB'; untaint_all z2h-selftest" >/dev/null 2>&1
  kubectl cordon "$node" >/dev/null 2>&1
  got=$(bash -c "source '$LIB'; schedulable_node_count" 2>&1)
  kubectl uncordon "$node" >/dev/null 2>&1
  check "a cordoned node lowers the count ($got = $((want - 1)))" rc_is "$got" "$((want - 1))" || f=1
  return $f
}

test_fresh_ns_refuses_leftover_k16_taint() {
  local f=0 out rc
  kubectl taint nodes --all z2h-vip=true:NoSchedule --overwrite >/dev/null 2>&1
  out=$(bash -c "source '$LIB'; fresh_ns k-94-selftest" 2>&1); rc=$?
  check "fresh_ns dies with a leftover z2h-vip taint" [ "$rc" -ne 0 ] || f=1
  check "message names K16's cleanup.sh" has "$out" "16-game-server-vip-node/cleanup.sh" || f=1
  check "no namespace was created" no_ns k-94-selftest || f=1
  bash -c "source '$LIB'; untaint_all z2h-vip" >/dev/null 2>&1
  bash -c "source '$LIB'; fresh_ns k-94-selftest" >/dev/null 2>&1; check "fresh_ns works again after untaint" rc_is "$?" 0 || f=1
  bash -c "source '$LIB'; delete_ns k-94-selftest" >/dev/null 2>&1
  return $f
}

ms_available() { [ "$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)" = "True" ]; }
ms_absent() { ! kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; }

test_metrics_server_kept_if_preexisting() {
  local f=0 out
  if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
    printf '    skip: the test cluster already has metrics-server\n'
    return 0
  fi
  # Case 1: we installed it -> remove deletes it, and leaves an unlabelled neighbour alone.
  out=$(bash -c "source '$LIB'; ensure_metrics_server k99" 2>&1); check "ensure_metrics_server k99 returns 0" rc_is "$?" 0 || f=1
  check "APIService Available" ms_available || f=1
  check "kubectl top nodes works" kubectl top nodes >/dev/null 2>&1 || f=1
  out=$(bash -c "source '$LIB'; ensure_metrics_server k99" 2>&1)
  check "second call says already present" has "$out" "metrics-server already present" || f=1
  kubectl create configmap z2h-selftest-dummy -n kube-system --from-literal=a=b >/dev/null 2>&1
  check "labelled objects found (nothing_left would fail)" fails nothing_left_k8s k99 || f=1
  bash -c "source '$LIB'; remove_metrics_server_if_ours k99" >/dev/null 2>&1; check "remove returns 0" rc_is "$?" 0 || f=1
  check "APIService gone" ms_absent || f=1
  check "dummy object stays" kubectl get configmap z2h-selftest-dummy -n kube-system || f=1
  check "no k99-installed objects left" nothing_left_k8s k99 || f=1
  kubectl delete configmap z2h-selftest-dummy -n kube-system >/dev/null 2>&1
  # Case 2: pre-existing (label dropped) -> remove keeps it.
  bash -c "source '$LIB'; ensure_metrics_server k99" >/dev/null 2>&1
  kubectl label apiservice,deployment,service,serviceaccount,clusterrole,clusterrolebinding,rolebinding -A \
    -l z2h.scenario=k99-installed z2h.scenario- >/dev/null 2>&1
  bash -c "source '$LIB'; remove_metrics_server_if_ours k99" >/dev/null 2>&1
  check "unlabelled (pre-existing) APIService remains" kubectl get apiservice v1beta1.metrics.k8s.io || f=1
  # Clean up: delete what the manifest created.
  kubectl delete -f "$REPO/kubernetes/scenarios/_addons/metrics-server.yaml" --ignore-not-found >/dev/null 2>&1
  check "cluster back to no metrics-server" ms_absent || f=1
  return $f
}

test_metrics_server_never_adopts_foreign() {
  local f=0 out
  if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1 ||
     kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
    printf '    skip: the test cluster already has metrics-server\n'
    return 0
  fi
  # An unavailable, unlabelled Deployment named like metrics-server (z2h-selftest=dummy only marks it for the trap).
  kubectl create deployment metrics-server -n kube-system --image=busybox:1.36 --replicas=0 >/dev/null 2>&1
  kubectl label deployment metrics-server -n kube-system z2h-selftest=dummy >/dev/null 2>&1
  out=$(Z2H_MS_WAIT=4 bash -c "source '$LIB'; ensure_metrics_server k99" 2>&1)
  check "says it is not ours" has "$out" "not installed by us" || f=1
  check "our label was not added" [ -z "$(kubectl get deployment,apiservice,service -A -l z2h.scenario=k99-installed -o name 2>/dev/null)" ] || f=1
  check "nothing applied (no APIService)" ms_absent || f=1
  kubectl delete deployment metrics-server -n kube-system --ignore-not-found >/dev/null 2>&1
  return $f
}

test_nothing_left_detects_taint() {
  local f=0 node
  node=$(kubectl get nodes -o name | tail -n 1)
  check "clean cluster passes nothing_left_k8s" nothing_left_k8s k99 k-99-x || f=1
  kubectl taint nodes "${node#node/}" z2h-x=1:NoSchedule --overwrite >/dev/null 2>&1
  check "taint is detected" fails nothing_left_k8s k99 k-99-x || f=1
  bash -c "source '$LIB'; untaint_all z2h-x" >/dev/null 2>&1
  kubectl label "$node" z2h-lbl=1 --overwrite >/dev/null 2>&1
  check "label is detected" fails nothing_left_k8s k99 k-99-x || f=1
  kubectl label "$node" z2h-lbl- >/dev/null 2>&1
  check "clean again" nothing_left_k8s k99 k-99-x || f=1
  return $f
}

for t in test_no_cluster_message test_refuses_foreign_context test_lib_sourcing_is_quiet \
         test_cleanup_waits_for_namespace test_cleanup_stops_port_forward \
         test_showdown_configmap test_pod_reason test_fresh_ns_has_default_sa \
         test_run_cycle_k8s_happy_path test_run_cycle_k8s_failing_assert \
         test_untaint_all_is_idempotent test_schedulable_node_count test_fresh_ns_refuses_leftover_k16_taint \
         test_metrics_server_kept_if_preexisting test_metrics_server_never_adopts_foreign \
         test_nothing_left_detects_taint; do
  run_test "$t"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || { printf 'Failed:%s\n' "$FAILED_NAMES"; exit 1; }
