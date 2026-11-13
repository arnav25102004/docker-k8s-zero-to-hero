#!/usr/bin/env python3
"""S1.5 fix: the leftover finalizer is removed, so the pending delete can finish.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-37-stuck-pod"

z.need_cluster()
z.say("Removing the finalizer nobody is going to honour…")
if z.kubectl("patch", "pod", "old-stall", "-n", NS, "--type", "merge", "-p", '{"metadata":{"finalizers":null}}')[0] != 0:
    z.die("kubectl patch failed. Is the Pod still there? Check: kubectl get pods -n " + NS)
z.must_wait("the Pod to disappear", 60, lambda: not z.kubectl_ok("get", "pod", "old-stall", "-n", NS),
            "The Pod is still there. Check: kubectl get pod old-stall -n %s -o yaml" % NS)
z.show_next("✅ Fixed. The Pod is gone. Check it yourself:",
            "./check.sh   ·   kubectl get pods -n k-37-stuck-pod")
