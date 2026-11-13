#!/usr/bin/env python3
"""S2.2 fix: the readiness probe asks the right port, and the stuck Pod is replaced.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-15-statefulset"


def settled():
    return z.kubectl_out("get", "statefulset", "stall", "-n", NS, "-o", "jsonpath={.status.readyReplicas}") == "3"


z.need_cluster()
z.say("Pointing the readiness probe at the port the stall really listens on…")
z.apply_files(os.path.join(HERE, "app.yaml"))
# A StatefulSet will not replace a Pod that never became Ready (it waits for it). Delete the stuck Pod
# so the controller recreates it from the corrected template.
z.say("stall-0 never became Ready, so the StatefulSet would wait for it forever. Replacing it…")
z.kubectl("delete", "pod", "stall-0", "-n", NS, "--wait=false")
z.must_wait("all three stalls to open, one after another", 240, settled,
            "The stalls did not all open. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl get pods -n " + NS)
