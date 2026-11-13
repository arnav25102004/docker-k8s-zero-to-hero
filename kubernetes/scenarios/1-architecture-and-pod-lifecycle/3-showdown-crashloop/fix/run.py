#!/usr/bin/env python3
"""S1.3 fix: the same Deployment, with PORT set to the number 8080.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-03-crashloop"

z.need_cluster()
z.say("Correcting PORT (eighty → 8080)…")
z.apply_dir(HERE)
z.must_wait("the app to be rolled out and Ready", 180, lambda: z.rolled_out(NS, "showdown"),
            "The app didn't become Ready. Check: kubectl get pods -n " + NS)
# The old, crashing Pod is removed shortly after the new one is Ready: wait until only one Pod is left.
z.must_wait("the old crashing Pod to be removed", 60, lambda: z.only_one_pod(NS, "app=showdown"),
            "The old Pod is still there. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "showdown", 9203))
