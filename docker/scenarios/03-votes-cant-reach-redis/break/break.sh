#!/usr/bin/env bash
# D03 break: Redis and the Cats vs Dogs API both run, but the API is told Redis lives at "localhost".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

REDIS_IMAGE="redis:7.4.12-alpine"
PY_IMAGE="python:3.12-alpine"
API_IMAGE="d03-api:1.0"
API_SRC="$(cd "$HERE/../../../../apps/api" && pwd)"

not_ready() { curl -s --max-time 3 http://localhost:8103/readyz | grep -q "not ready"; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8103 || die "Port 8103 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "$REDIS_IMAGE" "about 17 MB"
ensure_image "$PY_IMAGE" "about 19 MB"

say "Building the Cats vs Dogs API image (a few seconds)…"
docker build -q --label z2h.scenario=d03 -t "$API_IMAGE" "$API_SRC" >/dev/null \
  || die "Could not build the API image from $API_SRC."

docker network create --label z2h.scenario=d03 d03-net >/dev/null || die "Could not create the network d03-net."
say "Starting Redis…"
docker run -d --name d03-redis --label z2h.scenario=d03 --network d03-net "$REDIS_IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"
say "Starting the voting API on port 8103…"
docker run -d --name d03-api --label z2h.scenario=d03 --network d03-net -p 8103:8080 \
  -e REDIS_HOST=localhost "$API_IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "the API to answer on port 8103" 30 not_ready \
  || die "The API didn't come up in time. Run cleanup.sh and try again."

show_next \
  "Both containers are Up. The voting booth is open at http://localhost:8103, so try a vote." \
  "curl -s localhost:8103/readyz"
