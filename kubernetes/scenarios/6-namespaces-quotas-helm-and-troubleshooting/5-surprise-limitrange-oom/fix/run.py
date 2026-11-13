#!/usr/bin/env python3
"""S6.5 fix: the same Deployment, now with an explicit resources section (requests 64Mi, limits 128Mi).

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-20-limitrange"

z.need_cluster()
z.say("Giving the app its own memory request (64Mi) and limit (128Mi)…")
z.apply_files(os.path.join(HERE, "app.yaml"))
if z.kubectl_show("rollout", "status", "deployment/showdown", "-n", NS, "--timeout=180s") != 0:
    z.die("The app didn't become Ready. Check: kubectl get pods -n " + NS)
# The old crash-looping Pods are removed shortly after the new ones are Ready: wait until only the 2 new ones are left.
z.must_wait("the old crashing Pods to be removed", 60, lambda: z.pod_count(NS, "app=showdown") == 2,
            "Extra Pods are still there. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "showdown", 9220))
