#!/usr/bin/env python3
"""S6.1 fix: the current context now points at the namespace the canteen lives in.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-38-night-canteen"

z.need_cluster()
z.say("Pointing your current context at the namespace %s…" % NS)
if z.kubectl("config", "set-context", "--current", "--namespace=" + NS)[0] != 0:
    z.die("Could not change the current context. Check: kubectl config get-contexts")
z.show_next("✅ Done. A plain 'kubectl get pods' now looks in %s. Check it yourself:" % NS,
            "./check.sh   ·   kubectl get pods   ·   (to undo later: python3 cleanup.py)")
