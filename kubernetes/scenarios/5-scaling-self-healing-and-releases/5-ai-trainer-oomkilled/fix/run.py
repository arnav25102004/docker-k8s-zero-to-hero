#!/usr/bin/env python3
"""S5.5 fix: the same trainer with a 256Mi memory limit (request 200Mi), so it can finish.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-08-oomkilled"

z.need_cluster()
z.say("Raising the memory limit to 256Mi…")
z.apply_dir(HERE)
z.must_wait("the trainer to be rolled out", 180, lambda: z.rolled_out(NS, "trainer"),
            "The trainer didn't become Ready. Check: kubectl get pods -n " + NS)
z.must_wait("the model to finish training", 60, lambda: z.logs_contain(NS, "model trained", "-l", "app=trainer"),
            "The training didn't finish. Check: kubectl logs -n %s -l app=trainer" % NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            "kubectl logs -n %s -l app=trainer" % NS)
