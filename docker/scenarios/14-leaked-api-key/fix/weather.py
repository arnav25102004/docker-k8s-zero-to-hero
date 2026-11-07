import os
import sys

# The key comes from the WEATHER_API_KEY environment variable (docker run -e ...).
# Fallback: a "key=..." line in /app/config, the old way before secrets.
key = os.environ.get("WEATHER_API_KEY")
if not key and os.path.exists("/app/config"):
    with open("/app/config") as f:
        key = f.read().strip().replace("key=", "", 1)

if not key:
    print("No WEATHER_API_KEY set. The widget needs a key to start.")
    print("Run it with:  docker run --rm -e WEATHER_API_KEY=<your key> <image>")
    sys.exit(1)

print("Bengaluru weather widget")
print("  Key accepted: " + key[:8] + "...")
print("  Today: 27 C, light rain after 4 pm. Carry an umbrella.")
print("  (Demo forecast: this app makes no network calls.)")
