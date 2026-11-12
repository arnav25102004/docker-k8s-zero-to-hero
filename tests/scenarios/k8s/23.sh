#!/usr/bin/env bash
# Spec for scenario K23 (23-dark-mode-not-applied). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-23-dark-mode"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

# in_cluster_body NS URL: the response BODY (whitespace removed) seen from inside the cluster, or "none".
# Kept in this spec on purpose: the shared lib only returns status codes.
in_cluster_body() {
  local ns="$1" url="$2" out=""
  out=$(in_cluster_pod "$ns" "" curl -s --max-time 5 "$url" | tr -d '[:space:]')
  printf '%s\n' "${out:-none}"
}

broken() {
  assert_eq "$(kubectl get configmap ui-settings -n k-23-dark-mode -o jsonpath='{.data.THEME}' 2>&1)" "dark" "the ConfigMap says dark"
  assert_eq "$(in_cluster_body k-23-dark-mode http://theme/theme)" "light" "the page still answers light"
}

fixed() {
  kubectl rollout status deployment/theme -n k-23-dark-mode --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "theme Deployment rolled out"
  # The old Pod may still be answering for a moment while the Service updates: allow a short settle time.
  local i body=""
  for i in 1 2 3 4 5 6; do
    body=$(in_cluster_body k-23-dark-mode http://theme/theme)
    [ "$body" = "dark" ] && break
    sleep 2
  done
  assert_eq "$body" "dark" "the page answers dark"
}
