#!/usr/bin/env python3
"""S3.3 fix: one changed env var (REDIS_HOST) is a Pod template change, so the Deployment rolls out a new Pod.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

APP = "k-12-dns-app"

z.need_cluster()
z.say("Pointing the app at Redis by its full name…")
z.apply_files(os.path.join(HERE, "app.yaml"))
z.say("Waiting for the new Pod to roll out…")
if z.kubectl("rollout", "status", "deployment/showdown", "-n", APP, "--timeout=180s")[0] != 0:
    z.die("The app didn't roll out. Check: kubectl get pods -n " + APP)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + APP,
            z.forward_hint(APP, "showdown", 9212))
