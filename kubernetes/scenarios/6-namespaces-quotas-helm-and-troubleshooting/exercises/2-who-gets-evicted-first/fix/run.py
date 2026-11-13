#!/usr/bin/env python3
"""S6.x2 fix: cache is Guaranteed, web is Burstable, batch is BestEffort.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-42-qos"


def settled():
    return all(z.rolled_out(NS, name) for name in ("cache", "web", "batch"))


z.need_cluster()
z.say("Giving each workload the class it deserves…")
z.apply_dir(HERE)
# apply only adds/changes fields; the batch job must LOSE its resources block
z.kubectl("patch", "deployment", "batch", "-n", NS, "--type", "json",
          "-p", '[{"op":"remove","path":"/spec/template/spec/containers/0/resources"}]')
z.must_wait("all three to settle", 180, settled, "It did not settle. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:", "./check.sh")
