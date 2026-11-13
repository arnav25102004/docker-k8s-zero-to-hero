#!/usr/bin/env python3
"""S4.3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-10-pvc-pending"


def pvc_pending():
    # The intended failure: PVC Pending, and the cluster has said why (an event names fast-ssd).
    return z.kubectl_out("get", "pvc", "board-data", "-n", NS, "-o", "jsonpath={.status.phase}") == "Pending"


def pod_pending():
    return z.kubectl_out("get", "pod", "-n", NS, "-l", "app=board", "-o", "jsonpath={.items[0].status.phase}") == "Pending"


z.start_break(SCENARIO, [NS], port=9210)
z.say("Deploying Kanboard with its disk request, a Service and a visitor…")
z.apply_dir(HERE)
# NOT "rollout status": it waits for Ready, which never happens here (that is the bug).
z.must_wait("the visitor to start (the first download can take a minute)", 180, lambda: z.visitor_running(NS),
            "The visitor Pod didn't start. Run cleanup.py and try again.")
z.must_wait("the disk request (PVC) to be Pending", 60, pvc_pending,
            "The PVC never showed as Pending. Run cleanup.py and try again.")
z.must_wait("the cluster to explain why", 60, lambda: z.events_contain(NS, "fast-ssd"),
            "No event mentioned fast-ssd. Run cleanup.py and try again.")
z.must_wait("the Kanboard Pod to be Pending", 60, pod_pending,
            "Expected the Pod to be Pending. Run cleanup.py and try again.")
z.must_wait("the visitor to report a failure", 60, lambda: z.visitor_failing(NS),
            "The visitor never reported a failure. Run cleanup.py and try again.")
z.scene_set()
