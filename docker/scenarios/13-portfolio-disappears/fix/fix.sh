#!/usr/bin/env bash
# D13 fix: run the same image without the bind mount, so nginx serves the website baked into the image.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

app_answers() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://localhost:8113)" = "200" ]; }

need_docker
cd "$HERE" || die "Could not enter $HERE"
docker image inspect d13-site:1.0 >/dev/null 2>&1 || {
  say "Building Priya's portfolio: docker build -t d13-site:1.0 ."
  docker build -q --label z2h.scenario=d13 -t d13-site:1.0 . >/dev/null \
    || die "The build failed. Try: docker build -t d13-site:1.0 ."
}
docker rm -f d13-site >/dev/null 2>&1
say "Starting it again, no mount: docker run -d --name d13-site -p 8113:80 d13-site:1.0"
docker run -d --name d13-site --label z2h.scenario=d13 -p 8113:80 d13-site:1.0 >/dev/null \
  || die "docker run failed. Is port 8113 free?"

wait_for "the portfolio to answer on port 8113" 30 app_answers \
  || die "The page didn't answer. Check: docker logs d13-site"

show_next "✅ Fixed. Now verify it yourself:" \
  "curl -s -o /dev/null -w '%{http_code}\\n' localhost:8113"
