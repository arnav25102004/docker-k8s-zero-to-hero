#!/usr/bin/env bash
# D03 fix: same API, but REDIS_HOST is the Redis container's name on d03-net.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

API_IMAGE="d03-api:1.0"

ready() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8103/readyz)" = "200" ]; }

need_docker
say "Recreating the API with REDIS_HOST=d03-redis (the Redis container's name on d03-net)"
docker rm -f d03-api >/dev/null 2>&1
docker run -d --name d03-api --label z2h.scenario=d03 --network d03-net -p 8103:8080 \
  -e REDIS_HOST=d03-redis "$API_IMAGE" >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "the API to be ready on port 8103" 30 ready \
  || die "The API didn't become ready. Check: docker logs d03-api"

show_next "✅ Fixed. Now verify it yourself:" \
  "curl -s localhost:8103/readyz" \
  "Then vote at http://localhost:8103 and run: curl -s localhost:8103/api/results"
