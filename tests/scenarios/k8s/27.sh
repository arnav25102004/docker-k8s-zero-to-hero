#!/usr/bin/env bash
# Spec for scenario K27 (27-dashboard-config-missing-key). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-27-config-key"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

# in_cluster_body NS URL: the response BODY (whitespace removed) seen from inside the cluster, or "none".
# Kept in this spec on purpose: the shared lib only returns status codes.
in_cluster_body() {
  local ns="$1" url="$2" out="" try
  # `kubectl run --rm -i` can lose the output of a Pod that exits instantly: retry a couple of times.
  for try in 1 2 3; do
    out=$(kubectl run "ibody-$$-$RANDOM" -n "$ns" --rm -i --restart=Never --quiet \
      --image=curlimages/curl:8.11.1 --command -- \
      curl -s --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]')
    [ -n "$out" ] && break
  done
  printf '%s\n' "${out:-none}"
}

# http_code NS URL: in_cluster_http, retried (a throwaway curl Pod can lose its output).
http_code() {
  local c="" try
  for try in 1 2 3; do
    c=$(in_cluster_http "$1" "$2")
    [ "$c" != "000" ] && break
    sleep 2
  done
  printf '%s\n' "$c"
}

broken() {
  # "More than 30 s": let the Pod age, then check it is still stuck.
  sleep 30
  assert_eq "$(pod_reason k-27-config-key app=dashboard)" "ContainerCreating" "the dashboard Pod is still ContainerCreating after 30 s"
  # Wording differs a little by version, so only the event reason is checked.
  assert_contains "$(kubectl get events -n k-27-config-key 2>&1)" "FailedMount" "the events contain FailedMount"
}

fixed() {
  kubectl rollout status deployment/dashboard -n k-27-config-key --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "dashboard Deployment rolled out"
  assert_eq "$(http_code k-27-config-key http://dashboard)" "200" "dashboard answers 200 inside the cluster"
  assert_contains "$(in_cluster_body k-27-config-key http://dashboard/assets/config.yml)" "Canteenmenu" "the served config holds a link title from the new config"
}
