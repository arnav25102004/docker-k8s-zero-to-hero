#!/usr/bin/env python3
"""S1.x3 fix: point the log shipper at the file the web container really writes.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-29-sidecar"

z.need_cluster()
z.say("Fixing the log shipper's setting…")
# A Pod template can be changed in place: the Deployment replaces the old Pod with a new one.
if z.kubectl("apply", "-f", os.path.join(HERE, "app.yaml"))[0] != 0:
    z.die("kubectl apply failed. Is the cluster healthy?")
z.say("Waiting for the rollout…")
if z.kubectl_show("rollout", "status", "deployment/notice", "-n", NS, "--timeout=180s") != 0:
    z.die("The notice board didn't roll out. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "notice", 9229))
