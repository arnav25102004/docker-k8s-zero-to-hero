#!/usr/bin/env bash
# D03 break: build the voting API from your own Dockerfile, then start Redis and the API on one network.
# Every Docker command is printed (after the ▶ $) exactly as it runs, so you can type them yourself.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"
refuse_if_in_work "$HERE"

not_ready() { curl -s --max-time 3 http://localhost:8103/readyz | grep -q "not ready"; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8103 || die "Port 8103 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
ensure_image "redis:7.4.12-alpine" "about 17 MB"
ensure_image "python:3.12-alpine" "about 19 MB"

cd "$HERE/.." || die "Could not enter the scenario folder."

prepare_work "$HERE"
run_shown docker build -t d03-api:1.0 work || die "The build failed. Read the message above."
run_shown docker network create d03-net || die "Could not create the network d03-net."
run_shown docker run -d --name d03-redis --network d03-net redis:7.4.12-alpine || die "docker run failed. Is Docker healthy?"
run_shown docker run -d --name d03-api --network d03-net -p 8103:8080 d03-api:1.0 || die "docker run failed. Is port 8103 free?"

wait_for "the API to answer on port 8103" 30 not_ready \
  || die "The API didn't come up in time. Run cleanup.sh and try again."

show_next \
  "Both containers are Up. The voting booth is open at http://localhost:8103 (playground: the port 8103 URL), so try a vote." \
  "curl -s localhost:8103/readyz"
