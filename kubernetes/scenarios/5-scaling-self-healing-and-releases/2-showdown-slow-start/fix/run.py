#!/usr/bin/env python3
"""S5.2 fix: the same Deployment, plus a startupProbe that gives the app up to 60 s to wake up.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-07-slow-start"

z.need_cluster()
z.say("Adding a startupProbe (up to 60 s to wake up)…")
z.apply_dir(HERE)
z.must_wait("the app to be rolled out and Ready (the app needs about 20 s)", 180, lambda: z.rolled_out(NS, "showdown"),
            "The app didn't become Ready. Check: kubectl get pods -n " + NS)
# The old, restarting Pod is removed shortly after the new one is Ready: wait until only one Pod is left.
z.must_wait("the old restarting Pod to be removed", 60, lambda: z.only_one_pod(NS, "app=showdown"),
            "The old Pod is still there. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "showdown", 9207))
