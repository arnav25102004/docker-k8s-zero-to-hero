#!/usr/bin/env python3
"""S5.3 fix: the same Deployment, now with a CPU request of 100m and a limit of 200m.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-25-hpa"


def scaled_up():
    # A number (not <unknown>) in the CPU reading, and more than one replica.
    util = z.kubectl_out("get", "hpa", "showdown", "-n", NS, "-o",
                         "jsonpath={.status.currentMetrics[0].resource.current.averageUtilization}")
    current = z.kubectl_out("get", "hpa", "showdown", "-n", NS, "-o", "jsonpath={.status.currentReplicas}") or "1"
    return util != "" and current.isdigit() and int(current) >= 2


z.need_cluster()
z.say("Telling Kubernetes how much CPU the app asks for (request 100m, limit 200m)…")
z.apply_files(os.path.join(HERE, "app.yaml"))
if z.kubectl_show("rollout", "status", "deployment/showdown", "-n", NS, "--timeout=180s") != 0:
    z.die("The app didn't become Ready. Check: kubectl get pods -n " + NS)
z.say("The first CPU readings take about a minute, then the autoscaler checks every ~15 seconds.")
z.must_wait("the autoscaler to read CPU and add a replica", 240, scaled_up,
            "No scale-up within 240s. Check: kubectl get hpa -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get hpa -n " + NS,
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "showdown", 9225))
