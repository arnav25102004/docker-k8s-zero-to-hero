#!/usr/bin/env bash
# D03 fix: start the API again, this time telling it where Redis lives when the container starts.
# The Dockerfile and the image stay exactly as they are; only the run line gains one flag.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"
refuse_if_in_work "$HERE"

ready() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8103/readyz)" = "200" ]; }

need_docker
cd "$HERE/.." || die "Could not enter the scenario folder."
docker image inspect d03-api:1.0 >/dev/null 2>&1 || die "Run ./break.sh first: there is no d03-api:1.0 image yet."

run_shown_quiet docker rm -f d03-api || true
run_shown docker run -d --name d03-api --network d03-net -p 8103:8080 -e REDIS_HOST=d03-redis d03-api:1.0 \
  || die "docker run failed. Did break.sh run first?"

wait_for "the API to be ready on port 8103" 30 ready \
  || die "The API didn't become ready. Check: docker logs d03-api"

show_next "✅ Fixed. Now verify it yourself:" \
  "curl -s localhost:8103/readyz" \
  "Then vote at http://localhost:8103 and run: curl -s localhost:8103/api/results"
