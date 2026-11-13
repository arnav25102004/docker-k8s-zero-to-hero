#!/usr/bin/env python3
"""S4.1 fix: restart the Deployment, so the Pod starts again with the current ConfigMap values.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-23-dark-mode"

z.need_cluster()
z.say("Restarting the theme Deployment…")
if z.kubectl("rollout", "restart", "deployment/theme", "-n", NS)[0] != 0:
    z.die("kubectl rollout restart failed. Is the scenario running? Try break first.")
if z.kubectl("rollout", "status", "deployment/theme", "-n", NS, "--timeout=180s")[0] != 0:
    z.die("The page didn't become Ready. Check: kubectl get pods -n " + NS)
# The old Pod pauses briefly before it stops (preStop): wait until only the new Pod is left.
z.must_wait("the old Pod to be removed", 60, lambda: z.only_one_pod(NS, "app=theme"),
            "The old Pod is still there. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "theme", 9223))
