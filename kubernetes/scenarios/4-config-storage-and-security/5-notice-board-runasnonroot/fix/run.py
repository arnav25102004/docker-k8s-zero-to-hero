#!/usr/bin/env python3
"""S4.5 fix: the board runs on an image that starts as a normal user (nginx-unprivileged, port 8080). The policy stays.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-21-nonroot"

z.need_cluster()
z.say("Switching the board to an image that runs as a normal user…")
# A Pod template can be changed in place: the Deployment replaces the stuck Pods with new ones.
z.apply_files(os.path.join(HERE, "app.yaml"))
z.say("Waiting for the rollout (the first time, the nginx-unprivileged image downloads now: up to a minute or two)…")
if z.kubectl_show("rollout", "status", "deployment/board", "-n", NS, "--timeout=180s") != 0:
    z.die("The board didn't roll out. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "board", 9221))
