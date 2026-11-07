#!/usr/bin/env bash
# Spec for scenario D14 (14-leaked-api-key). Sourced by tests/scenarios/docker.sh.

broken() {
  assert_eq "$([ "$(docker history --no-trunc d14-weather:broken | grep -c z2h-demo-key)" -ge 1 ] && echo yes || echo no)" "yes" "the key is readable in docker history of d14-weather:broken"
  assert_eq "$(docker run --rm d14-weather:broken cat /app/config)" "key=z2h-demo-key-NOT-REAL-123" "the key is also baked into /app/config"
  assert_eq "$(docker images -q d14-weather:shared)" "$(docker images -q d14-weather:broken)" "d14-weather:shared is the same image"
}

fixed() {
  assert_eq "$(docker history --no-trunc d14-weather:fixed | grep -c z2h-demo-key)" "0" "the key is NOT in docker history of d14-weather:fixed"
  assert_contains "$(docker run --rm -e WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123 d14-weather:fixed 2>&1)" "Bengaluru weather" "the fixed image prints the forecast when given the key at runtime"
  assert_eq "$(docker run --rm d14-weather:fixed ls /app)" "weather.py" "no config file in the fixed image"
}
