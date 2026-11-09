#!/usr/bin/env bash
# D14 fix: rebuilds the image with a BuildKit build secret instead of an ARG, then runs it with the key passed at runtime (-e).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

# A fake demo value. Never use a real key in class.
export WEATHER_API_KEY="z2h-demo-key-NOT-REAL-123"

need_docker
cd "$HERE" || die "Could not enter $HERE"
say "Rebuilding with a build secret: docker build --secret id=weather_key,env=WEATHER_API_KEY -t d14-weather:fixed fix"
docker build --label z2h.scenario=d14 --secret id=weather_key,env=WEATHER_API_KEY -t d14-weather:fixed . \
  || die "The build failed. Is Docker up to date? Try: docker version"
say "Running it, with the key given at runtime: docker run --rm -e WEATHER_API_KEY=<demo key> d14-weather:fixed"
docker run --rm --label z2h.scenario=d14 -e WEATHER_API_KEY d14-weather:fixed \
  || die "The widget did not start. Try: docker run --rm -e WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123 d14-weather:fixed"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker history --no-trunc d14-weather:fixed | grep z2h-demo-key"
