#!/usr/bin/env python3
"""S5.4 fix: roll back to the previous revision (the good v1).

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-11-bad-rollout"

z.need_cluster()
z.say("Rolling back (kubectl rollout undo)…")
# kubectl prints a long (harmless) warning about "kubectl apply" here; keep it for errors only.
code, output = z.kubectl_all("rollout", "undo", "deployment/showdown", "-n", NS)
if code != 0:
    z.die("rollout undo failed: " + output)
if z.kubectl_show("rollout", "status", "deployment/showdown", "-n", NS, "--timeout=180s") != 0:
    z.die("The rollback didn't finish. Check: kubectl get pods -n " + NS)
# The crashing Pod is removed as part of the rollback; make sure only the 3 good Pods remain.
z.must_wait("only the 3 good Pods to remain", 60, lambda: z.pod_count(NS, "app=showdown") == 3,
            "Extra Pods are still there. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl rollout history deployment/showdown -n " + NS,
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "showdown", 9211))
