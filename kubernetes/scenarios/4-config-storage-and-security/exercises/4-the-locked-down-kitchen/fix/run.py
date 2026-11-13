#!/usr/bin/env python3
"""S4.x4 fix: the checklist is complete AND the image really runs as a normal user (unprivileged nginx on 8080).

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-45-lockdown"


def settled():
    return z.kubectl_out("get", "deployment", "kitchen", "-n", NS, "-o", "jsonpath={.status.readyReplicas}") == "2"


z.need_cluster()
z.say("Completing the checklist and switching to an image that can obey it…")
z.apply_dir(HERE)
z.must_wait("the kitchen to open", 180, settled, "It did not settle. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl logs visitor -n k-45-lockdown --tail=3")
