#!/usr/bin/env python3
"""S6.3 fix: roll the release back to revision 1 with Helm.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-27-helm"

z.need_cluster()
z.need_helm()
z.say("Rolling the release back to revision 1…")
if z.helm("rollback", "stall", "1", "-n", NS, "--wait", "--timeout", "3m") != 0:
    z.die("helm rollback failed. Check: helm history stall -n " + NS)
z.must_wait("the Pods to settle", 120, lambda: z.check_rollouts(NS, quiet=True),
            "It did not settle. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   helm history stall -n " + NS)
