#!/usr/bin/env python3
"""S1.1 fix: the same Deployment, with a realistic memory request (64Mi) and a limit (128Mi).

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-01-pending"

z.need_cluster()
z.say("Applying the corrected requests (64Mi memory, 50m CPU) and a 128Mi limit…")
z.apply_dir(HERE)
z.must_wait("the whiteboard Pod to be Ready", 180, lambda: z.rolled_out(NS, "draw"),
            "The Pod didn't become Ready. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "draw", 9201))
