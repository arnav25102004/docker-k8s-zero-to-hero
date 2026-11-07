#!/usr/bin/env bash
# D15 fix: a healthcheck on db plus depends_on condition: service_healthy makes app wait until Postgres is ready.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

db_healthy() { [ "$(docker inspect -f '{{.State.Health.Status}}' d15-db-1 2>/dev/null)" = "healthy" ]; }
app_serving() { [ "$(curl -s -o /dev/null --max-time 2 -w '%{http_code}' http://localhost:8115)" = "200" ]; }

need_docker
say "Applying the fixed compose.yaml: docker compose -p d15 up -d"
docker compose -p d15 -f "$HERE/compose.yaml" up -d >/dev/null 2>&1 \
  || die "docker compose up failed. Try: docker compose -p d15 -f $HERE/compose.yaml up"
wait_for "the database to be healthy" 60 db_healthy \
  || die "The database never became healthy. Check: docker compose -p d15 logs db"
wait_for "the app to answer" 30 app_serving \
  || die "The app didn't answer. Check: docker compose -p d15 logs app"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker compose -p d15 ps"
