#!/usr/bin/env python3
"""S2.1 fix: the label now sits on the Pod template, where the Service looks.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-32-wrong-object"


def has_endpoints():
    return z.kubectl_out("get", "endpointslices", "-n", NS, "-l", "kubernetes.io/service-name=samosa",
                         "-o", "jsonpath={..addresses}") != ""


z.need_cluster()
z.say("Moving the label onto the Pod template (Pods get replaced one by one)…")
z.apply_files(os.path.join(HERE, "app.yaml"))
if z.kubectl("rollout", "status", "deployment/samosa", "-n", NS, "--timeout=180s")[0] != 0:
    z.die("The rollout did not finish. Check: kubectl get pods -n " + NS)
z.must_wait("the Service to find its Pods", 60, has_endpoints,
            "The Service still has no endpoints. Check: kubectl get endpointslices -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl logs visitor -n k-32-wrong-object --tail=3")
