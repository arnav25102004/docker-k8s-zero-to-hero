#!/usr/bin/env bash
# Spec for scenario D13 (13-portfolio-disappears). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$(container_state d13-site)" "running" "container d13-site is running"
  assert_eq "$(http_code http://localhost:8113)" "403" "localhost:8113 answers 403 (nginx has no index to show)"
  assert_eq "$(docker exec d13-site ls /usr/share/nginx/html)" "TODO.txt" "the folder holds only TODO.txt"
  local img
  img="$(docker run --rm d13-site:1.0 ls /usr/share/nginx/html 2>&1)"
  assert_contains "$img" "index.html" "the website IS in the image (index.html)"
}

fixed() {
  assert_eq "$(http_code http://localhost:8113)" "200" "portfolio answers 200 on :8113"
  assert_contains "$(curl -s --max-time 5 http://localhost:8113)" "Priya Nair" "the page contains the portfolio title"
  assert_eq "$(docker inspect -f '{{len .Mounts}}' d13-site)" "0" "no mounts on d13-site"
}
