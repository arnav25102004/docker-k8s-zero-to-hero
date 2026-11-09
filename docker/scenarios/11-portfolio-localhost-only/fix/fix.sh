#!/usr/bin/env bash
# D11 fix: rebuild with --bind 0.0.0.0 so the server listens on every interface, then run it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

app_answers() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://localhost:8111)" = "200" ]; }

need_docker
cd "$HERE" || die "Could not enter $HERE"
say "Rebuilding with the fixed Dockerfile: docker build -t d11-portfolio:1.0 fix"
docker build -q --label z2h.scenario=d11 -t d11-portfolio:1.0 . >/dev/null \
  || die "The build failed. Try: docker build -t d11-portfolio:1.0 fix"
docker rm -f d11-portfolio >/dev/null 2>&1
say "Starting it again: docker run -d --name d11-portfolio -p 8111:8000 d11-portfolio:1.0"
docker run -d --name d11-portfolio --label z2h.scenario=d11 -p 8111:8000 d11-portfolio:1.0 >/dev/null \
  || die "docker run failed. Is port 8111 free?"

wait_for "the portfolio to answer on port 8111" 30 app_answers \
  || die "The page didn't answer. Check: docker logs d11-portfolio"

show_next "✅ Fixed. Now verify it yourself:" \
  "curl -s -o /dev/null -w '%{http_code}\\n' localhost:8111"
