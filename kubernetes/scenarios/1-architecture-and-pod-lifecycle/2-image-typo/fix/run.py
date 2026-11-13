#!/usr/bin/env python3
"""S1.2 fix: the same Deployment, with the image name spelled correctly (excalidraw).

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-02-image-typo"

z.need_cluster()
z.say("Correcting the image name (excalidrw → excalidraw)…")
z.apply_dir(HERE)
z.must_wait("the whiteboard Pod to be Ready", 180, lambda: z.rolled_out(NS, "draw"),
            "The Pod didn't become Ready. Check: kubectl get pods -n " + NS)
# The old, stuck Pod is removed shortly after the new one is Ready: wait until only one whiteboard Pod is left.
z.must_wait("the old stuck Pod to be removed", 60, lambda: z.only_one_pod(NS, "app=draw"),
            "The old Pod is still there. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "draw", 9202))
