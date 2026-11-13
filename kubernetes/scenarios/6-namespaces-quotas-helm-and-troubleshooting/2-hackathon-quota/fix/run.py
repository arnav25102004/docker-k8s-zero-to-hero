#!/usr/bin/env python3
"""S6.2 fix: the same dashboard, with requests and limits small enough to fit the quota.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-19-hackathon"

z.need_cluster()
z.say("Giving the dashboard Pods requests and limits that fit the quota…")
z.apply_dir(HERE)
z.must_wait("both dashboard Pods to be Ready", 180, lambda: z.rolled_out(NS, "dashboard"),
            "The dashboard didn't become Ready. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get deployment,pods -n " + NS,
            "kubectl describe quota -n " + NS,
            z.forward_hint(NS, "dashboard", 9219))
