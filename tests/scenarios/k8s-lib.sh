#!/usr/bin/env bash
# Test helpers for the Kubernetes scenario harness. Sourced by k8s.sh and the
# self-test. Builds on lib.sh (asserts, _step, _check).
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# require_test_cluster: refuse to run against anything but the throwaway kind cluster.
require_test_cluster() {
  local ctx
  ctx=$(kubectl config current-context 2>/dev/null)
  if [ -n "${Z2H_DRY_RUN_CONTEXT:-}" ]; then
    if [ "$ctx" = "$Z2H_DRY_RUN_CONTEXT" ]; then
      printf '⚠ Dry run on context "%s": scenario namespaces (k-NN-*) on it will be deleted and recreated.\n' "$ctx" >&2
      return 0
    fi
    printf 'Refusing to run: Z2H_DRY_RUN_CONTEXT is "%s" but the current context is "%s".\n' "$Z2H_DRY_RUN_CONTEXT" "${ctx:-none}" >&2
    return 1
  fi
  if [ "$ctx" != "kind-z2h-test" ]; then
    printf 'Refusing to run: current kubectl context is "%s", not "kind-z2h-test".\n' "${ctx:-none}" >&2
    printf 'Create the test cluster and use it:\n  tests/scenarios/k8s-cluster.sh up\n  export KUBECONFIG=$HOME/.kube/z2h-test.config\n' >&2
    return 1
  fi
}

# in_cluster_pod NS OVERRIDES [COMMAND ARGS...]
# Run COMMAND in a throwaway curl Pod in NS and print what it wrote to stdout.
# It creates the Pod, waits for it to finish, then reads `kubectl logs`. It does NOT use
# `kubectl run -i --rm`: that attaches to the Pod, and when the Pod exits at once the
# attach can lose the output, which looked exactly like "connection refused" (000).
# OVERRIDES is "" or a --overrides JSON string; "@NAME@" in it becomes the Pod's name.
# If the helper Pod itself cannot run (image pull stuck, quota, scheduling) it retries,
# then prints the reason on stderr and returns 1. Wait and tries: Z2H_POD_WAIT (90 s) and
# Z2H_POD_TRIES (3).
in_cluster_pod() {
  local ns="$1" ov="$2" name i phase out why runerr try tries="${Z2H_POD_TRIES:-3}" wait="${Z2H_POD_WAIT:-90}"
  shift 2
  # A namespace that enforces Pod Security "restricted" (K44, K45) refuses a plain helper Pod,
  # so give the helper the same checklist the learner's Pods carry.
  if [ -z "$ov" ] && [ "$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)" = "restricted" ]; then
    # An override's container list replaces kubectl's own, so it must carry the image and command too.
    local a esc cmdjson=""
    for a in "$@"; do
      esc=${a//\\/\\\\}
      esc=${esc//\"/\\\"}
      cmdjson="${cmdjson:+$cmdjson,}\"$esc\""
    done
    [ -n "$cmdjson" ] && cmdjson=',"command":['"$cmdjson"']'
    ov='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":100,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"@NAME@","image":"curlimages/curl:8.11.1"'"$cmdjson"',"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}'
  fi
  for try in $(seq 1 "$tries"); do
    name="ic-$$-$RANDOM"
    runerr=""
    if [ -n "$ov" ] && [ "$#" -gt 0 ]; then
      runerr=$(kubectl run "$name" -n "$ns" --restart=Never --image=curlimages/curl:8.11.1 --overrides="${ov//@NAME@/$name}" --command -- "$@" 2>&1 >/dev/null)
    elif [ -n "$ov" ]; then
      runerr=$(kubectl run "$name" -n "$ns" --restart=Never --image=curlimages/curl:8.11.1 --overrides="${ov//@NAME@/$name}" 2>&1 >/dev/null)
    elif [ "$#" -gt 0 ]; then
      runerr=$(kubectl run "$name" -n "$ns" --restart=Never --image=curlimages/curl:8.11.1 --command -- "$@" 2>&1 >/dev/null)
    else
      runerr=$(kubectl run "$name" -n "$ns" --restart=Never --image=curlimages/curl:8.11.1 2>&1 >/dev/null)
    fi
    # "Warning: would violate PodSecurity" lines are not errors; keep only a real failure.
    runerr=$(printf '%s' "$runerr" | grep -v '^Warning' | head -n 3 | tr '\n' ' ')
    i=0
    phase=""
    while [ "$i" -lt "$wait" ]; do
      phase=$(kubectl get pod "$name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)
      case "$phase" in Succeeded | Failed) break ;; esac
      sleep 1
      i=$((i + 1))
    done
    case "$phase" in
      Succeeded | Failed)
        out=$(kubectl logs "$name" -n "$ns" 2>/dev/null)
        kubectl delete pod "$name" -n "$ns" --now --wait=false >/dev/null 2>&1
        printf '%s' "$out"
        return 0
        ;;
    esac
    why=$(kubectl get pod "$name" -n "$ns" -o jsonpath='{.status.phase}{" "}{.status.containerStatuses[0].state.waiting.reason}{" "}{.status.conditions[?(@.type=="PodScheduled")].message}' 2>/dev/null)
    [ -n "$runerr" ] && why="kubectl run said: $runerr"
    kubectl delete pod "$name" -n "$ns" --now --wait=false >/dev/null 2>&1
  done
  printf 'in_cluster_pod: the helper Pod never finished in namespace %s after %s tries (last state: %s)\n' "$ns" "$tries" "${why:-unknown}" >&2
  return 1
}

# in_cluster_http NS URL: HTTP status code seen from inside the cluster. 000 means curl itself
# could not connect (a real refusal or timeout). ERR means the helper Pod could not run, so
# nothing was tested (the reason is printed on stderr).
in_cluster_http() {
  local ns="$1" url="$2" out code
  out=$(in_cluster_pod "$ns" "" curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url") || { printf 'ERR\n'; return 0; }
  code=$(printf '%s' "$out" | grep -o '^[0-9][0-9][0-9]' | head -n 1)
  printf '%s\n' "${code:-000}"
}

# in_cluster_http_wait NS URL WANT [ATTEMPTS]: like in_cluster_http, but keeps asking (2 s apart)
# until the answer is WANT, then prints it; after ATTEMPTS tries (default 8) it prints the last
# answer. For checks right after a fix: a Deployment without a readiness probe counts as rolled
# out the moment its container starts, a few seconds before the app listens. A learner watches
# the visitor turn green; this does the same.
in_cluster_http_wait() {
  local ns="$1" url="$2" want="$3" max="${4:-8}" i=0 got=""
  while [ "$i" -lt "$max" ]; do
    got=$(in_cluster_http "$ns" "$url")
    [ "$got" = "$want" ] && break
    [ "$got" = "ERR" ] && break   # the helper Pod cannot run: more attempts only waste minutes
    i=$((i + 1))
    [ "$i" -lt "$max" ] && sleep 2
  done
  printf '%s\n' "$got"
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

# nothing_left_k8s ID NS...: no namespace, no port-forward, no labelled cluster-scoped object,
# no z2h-* node taint or label, and no object anywhere labelled z2h.scenario=ID-installed.
nothing_left_k8s() {
  local id="$1" ns left
  shift
  for ns in "$@"; do
    kubectl get namespace "$ns" >/dev/null 2>&1 && return 1
    pgrep -f "port-forward -n $ns" >/dev/null 2>&1 && return 1
  done
  left=$(kubectl get clusterroles,clusterrolebindings,persistentvolumes -l "z2h.scenario=$id" -o name 2>/dev/null)
  [ -z "$left" ] || return 1
  # Node taints / labels with a z2h- key prefix (K16 and friends).
  left=$(kubectl get nodes -o jsonpath='{range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}' 2>/dev/null | grep '^z2h-')
  [ -z "$left" ] || return 1
  # Label keys appear as JSON object keys ("z2h-foo": "value").
  left=$(kubectl get nodes -o json 2>/dev/null | grep -o '"z2h-[^"]*":')
  [ -z "$left" ] || return 1
  # Anything a scenario installed cluster-wide (e.g. metrics-server, ID k25). endpoints and
  # endpointslices are skipped: they are derived objects that briefly copy Service labels.
  local res
  res=$(kubectl api-resources --verbs=list -o name 2>/dev/null |
    grep -v -E '^(events|events\.events\.k8s\.io|endpoints|endpointslices\.discovery\.k8s\.io)$' | paste -sd, -)
  if [ -z "$res" ]; then
    printf 'nothing_left_k8s: could not list API resources, cannot verify leftovers\n' >&2
    return 1
  fi
  left=$(kubectl get "$res" -A -l "z2h.scenario=${id}-installed" -o name 2>/dev/null)
  [ -z "$left" ]
}

# run_cycle_k8s DIR ID NS...: cleanup -> break -> broken -> fix -> fixed -> cleanup
# -> nothing left. Twice. broken() and fixed() must be defined by the caller.
# If any step fails, the scenario's cleanup.sh runs before returning, so a failed
# scenario cannot leave things behind for the next one (K16 taints every node, and a
# leftover taint made every later scenario fail).
run_cycle_k8s() {
  local dir="$1"
  _run_cycle_k8s "$@" && return 0
  bash "$dir/cleanup.sh" >/dev/null 2>&1
  return 1
}

# The learner's ./check.sh ("am I done?") for K01 to K30. K31 and up test theirs inside their own
# spec. It must say "not done" while the scenario is broken and "done" once it is fixed.
_generic_check_broken() {
  [ -n "${GENERIC_CHECK:-}" ] || return 0
  assert_cmd_fails "check.sh says: not done yet" bash "$GENERIC_CHECK"
}
_generic_check_fixed() {
  [ -n "${GENERIC_CHECK:-}" ] || return 0
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    bash "$GENERIC_CHECK" >/dev/null 2>&1 && { printf '    ok: check.sh says: done\n'; return 0; }
    sleep 2
  done
  printf '    FAIL: check.sh still says not done 20 s after the fix:\n'
  bash "$GENERIC_CHECK" 2>&1 | sed 's/^/      | /'
  return 1
}

_run_cycle_k8s() {
  local dir="$1" id="$2" n
  shift 2
  GENERIC_CHECK=""
  case "$id" in k[0-2][0-9] | k30) [ -f "$dir/check.sh" ] && GENERIC_CHECK="$dir/check.sh" ;; esac
  for n in 1 2; do
    printf '  -- cycle %s/2\n' "$n"
    _step cleanup "$n" "$dir/cleanup.sh" || return 1
    _step break.sh "$n" "$dir/break/break.sh" || return 1
    _check broken "$n" broken || return 1
    _check "check.sh while broken" "$n" _generic_check_broken || return 1
    _step fix.sh "$n" "$dir/fix/fix.sh" || return 1
    _check fixed "$n" fixed || return 1
    _check "check.sh after the fix" "$n" _generic_check_fixed || return 1
    _step "final cleanup" "$n" "$dir/cleanup.sh" || return 1
    nothing_left_k8s "$id" "$@" || { printf '  FAILED at step: nothing-left check (cycle %s)\n' "$n"; return 1; }
  done
  return 0
}

# ---- Monitoring (scenarios K46 to K48) ----
# ensure_monitoring: install kube-prometheus-stack (lab K19) if Prometheus is not running. Never
# removes it: it is shared, slow to install, and cleanup must not tear it down between scenarios.
ensure_monitoring() {
  if kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -q Running; then
    return 0
  fi
  command -v helm >/dev/null 2>&1 || { printf 'helm is needed for the monitoring scenarios (K46 to K48).\n' >&2; return 1; }
  printf '  installing monitoring (kube-prometheus-stack): a few minutes the first time\n'
  bash "$REPO/scripts/install-monitoring.sh" >/dev/null 2>&1 || { printf 'monitoring install failed: run scripts/install-monitoring.sh to see why\n' >&2; return 1; }
}

_prom_urlencode() {
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

# prom_wait EXPR SECONDS: succeed as soon as Prometheus returns at least one series for EXPR.
prom_wait() {
  local expr="$1" max="$2" i=0 url
  url="/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/api/v1/query?query=$(_prom_urlencode "$expr")"
  while [ "$i" -lt "$max" ]; do
    kubectl get --raw "$url" 2>/dev/null | grep -q '"result":\[{' && return 0
    sleep 3
    i=$((i + 3))
  done
  return 1
}
