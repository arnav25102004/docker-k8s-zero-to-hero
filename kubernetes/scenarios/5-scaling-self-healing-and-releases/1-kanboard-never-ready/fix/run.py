#!/usr/bin/env python3
"""S5.1 fix: the readiness probe now checks /healthcheck.php, which Kanboard really serves.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-06-never-ready"

z.need_cluster()
z.say("Pointing the readiness probe at a path Kanboard really has (/healthz.php → /healthcheck.php)…")
# Changing the probe changes the Pod template, so Kubernetes rolls out a new Pod by itself.
z.apply_dir(HERE)
z.must_wait("the Kanboard Deployment to be Ready", 180, lambda: z.rolled_out(NS, "board"),
            "The Pod didn't become Ready. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "board", 9206))
