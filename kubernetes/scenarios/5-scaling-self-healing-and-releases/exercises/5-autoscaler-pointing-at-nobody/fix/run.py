#!/usr/bin/env python3
"""S5.x5 fix: the autoscaler now points at the Deployment that really exists.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-41-hpa-target"
ABLE = 'jsonpath={.status.conditions[?(@.type=="AbleToScale")].status}'

z.need_cluster()
z.say("Pointing the autoscaler at the right Deployment…")
z.apply_dir(HERE)
z.must_wait("the autoscaler to find its target", 180,
            lambda: z.kubectl_out("get", "hpa", "lassi", "-n", NS, "-o", ABLE) == "True",
            "It did not settle. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl describe hpa lassi -n k-41-hpa-target")
