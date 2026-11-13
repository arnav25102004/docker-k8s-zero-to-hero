#!/usr/bin/env python3
"""S1.4 fix: one word in the Pod template changes, so the Deployment rolls out a new Pod.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-26-init-stuck"

z.need_cluster()
z.say("Applying the corrected Deployment…")
if z.kubectl("apply", "-f", os.path.join(HERE, "app.yaml"))[0] != 0:
    z.die("kubectl apply failed. Is the cluster healthy?")
z.say("Waiting for the new Pod to roll out…")
if z.kubectl("rollout", "status", "deployment/showdown", "-n", NS, "--timeout=180s")[0] != 0:
    z.die("The app didn't roll out. Check: kubectl get pods -n " + NS)
# The old Pod is removed shortly after the new one is Ready: wait until only one Pod is left.
z.must_wait("the old Pod to be removed", 60, lambda: z.only_one_pod(NS, "app=showdown"),
            "The old Pod is still there. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "showdown", 9226))
