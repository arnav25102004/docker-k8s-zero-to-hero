#!/usr/bin/env bash
# D14 break: builds the weather widget with the API key passed as a build ARG and written by a RUN step,
# then "shares" the image by tagging it d14-weather:shared. The key is now saved inside the image.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

BASE_IMAGE="python:3.12-alpine"
# A fake demo value. Never use a real key in class.
DEMO_KEY="z2h-demo-key-NOT-REAL-123"

need_docker
bash "$HERE/../cleanup.sh"
ensure_image "$BASE_IMAGE" "about 19 MB"

cd "$HERE" || die "Could not enter $HERE"
say "Building the widget: docker build --build-arg WEATHER_API_KEY=<demo key> -t d14-weather:broken ."
docker build --label z2h.scenario=d14 --build-arg "WEATHER_API_KEY=$DEMO_KEY" -t d14-weather:broken . \
  || die "The build failed. Try again: docker build -t d14-weather:broken ."
say "Testing it: docker run --rm d14-weather:broken"
docker run --rm --label z2h.scenario=d14 d14-weather:broken
say "Sharing it with the team: docker tag d14-weather:broken d14-weather:shared"
docker tag d14-weather:broken d14-weather:shared

show_next \
  "The widget works and the image is 'shared' as d14-weather:shared. Nothing looks wrong." \
  "docker history d14-weather:broken"
