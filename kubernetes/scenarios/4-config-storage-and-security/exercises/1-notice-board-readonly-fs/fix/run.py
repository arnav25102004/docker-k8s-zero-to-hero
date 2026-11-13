#!/usr/bin/env python3
"""S4.x1 fix: keep the policy, give nginx a scratch folder (emptyDir) at /tmp, the one place it writes.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-22-readonly-fs"

z.need_cluster()
z.say("Giving the board a scratch folder where it needs to write…")
# A Pod template can be changed in place: the Deployment replaces the crashing Pods with new ones.
z.apply_files(os.path.join(HERE, "app.yaml"))
z.say("Waiting for the rollout…")
if z.kubectl_show("rollout", "status", "deployment/board", "-n", NS, "--timeout=180s") != 0:
    z.die("The board didn't roll out. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "board", 9222))
