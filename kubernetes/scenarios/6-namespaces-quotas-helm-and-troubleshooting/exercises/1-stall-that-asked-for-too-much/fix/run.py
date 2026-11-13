#!/usr/bin/env python3
"""S6.x1 fix: the memory limit now fits under the namespace maximum.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-40-limit-max"


def settled():
    return z.kubectl_out("get", "deployment", "chaat", "-n", NS, "-o", "jsonpath={.status.readyReplicas}") == "2"


z.need_cluster()
z.say("Asking for a memory limit the kitchen allows…")
z.apply_dir(HERE)
z.must_wait("the stall to open", 180, settled, "It did not settle. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl logs visitor -n k-40-limit-max --tail=3")
