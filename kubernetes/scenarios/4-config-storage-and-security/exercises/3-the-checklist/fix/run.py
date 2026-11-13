#!/usr/bin/env python3
"""S4.x3 fix: the Pod carries all four things the restricted level asks for.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-44-checklist"


def settled():
    return z.kubectl_out("get", "deployment", "cart", "-n", NS, "-o", "jsonpath={.status.readyReplicas}") == "2"


z.need_cluster()
z.say("Filling in the restricted checklist…")
z.apply_dir(HERE)
z.must_wait("the cart to open", 180, settled,
            "It did not settle. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl logs visitor -n k-44-checklist --tail=3")
