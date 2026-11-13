#!/usr/bin/env python3
"""S5.x1 fix: the readiness probe now rings the door the app really has (5678).

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-34-doorbell"

z.need_cluster()
z.say("Pointing the readiness probe at the right port…")
z.apply_dir(HERE)
z.must_wait("the new Pods to become Ready", 180, lambda: z.rolled_out(NS, "dosa"),
            "The rollout did not finish. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl logs visitor -n %s --tail=3" % NS)
