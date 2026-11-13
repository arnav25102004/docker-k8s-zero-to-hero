#!/usr/bin/env python3
"""S1.x2 fix: "never two on the same node" becomes "spread out if you can" (preferred anti-affinity).

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-18-anti-affinity"

z.need_cluster()
z.say("Turning the hard rule into a preference…")
z.apply_dir(HERE)
z.must_wait("whoami to be rolled out", 180, lambda: z.rolled_out(NS, "whoami"),
            "whoami didn't become Ready. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n %s -o wide" % NS,
            "kubectl port-forward -n %s svc/whoami 9218:80   (second terminal; then curl localhost:9218)" % NS)
