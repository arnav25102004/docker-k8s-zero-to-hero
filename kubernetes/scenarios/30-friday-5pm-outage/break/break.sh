#!/usr/bin/env bash
# K30 break: deploys the Friday release of Cats vs Dogs (app, database, Service) and a
# visitor, then waits until every Pod has settled into what the room will investigate.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-30-friday"

app_ready() {
  [ "$(kubectl get pods -n "$NS" -l app=showdown -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c '^true$')" = "2" ]
}
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
db_settled() {
  case "$(pod_reason "$NS" app=redis)" in
    ImagePullBackOff|ErrImagePull) return 0 ;;
  esac
  return 1
}

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9230 || die "Port 9230 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
create_showdown_configmap "$NS" || die "Could not create the ConfigMap showdown-code."

say "Shipping the Friday release: the Cats vs Dogs app, its database, its Service and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the app Pods to start (the first download can take a minute)" 180 app_ready \
  || die "The app Pods didn't start. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."
wait_for "the database Pod to settle" 180 db_settled \
  || die "The database Pod didn't settle into its failing state. Run cleanup.sh and try again."

show_next \
  "It's Friday, 5 PM, and the release is out. The visitor can't get an answer from the app. Watch it live in a second terminal and keep it open for the whole incident: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
