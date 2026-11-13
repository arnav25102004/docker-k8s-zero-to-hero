#!/usr/bin/env python3
"""S5.1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-06-never-ready"
BOARD = ["get", "pod", "-n", NS, "-l", "app=board", "-o"]


def not_ready():
    return z.kubectl_out(*BOARD, "jsonpath={.items[0].status.containerStatuses[0].ready}") == "false"


z.start_break(SCENARIO, [NS], port=9206)
z.say("Deploying Kanboard, its Service and a visitor…")
z.apply_dir(HERE)
# NOT "rollout status": it waits for Ready, which never happens here (that is the bug).
z.must_wait("the Kanboard Pod to start (the first download can take a minute)", 180,
            lambda: z.kubectl_out(*BOARD, "jsonpath={.items[0].status.phase}") == "Running",
            "The Pod didn't start. Run cleanup.py and try again.")
z.wait_visitor(NS)
# The intended failure: Running but not Ready, and the kubelet has reported the failed probe.
z.must_wait("the readiness probe to fail", 120, lambda: z.events_contain(NS, "Readiness probe failed"),
            "The probe never reported a failure. Run cleanup.py and try again.")
if not not_ready():
    z.die("Expected the Pod to be Running but not Ready. Run cleanup.py and try again.")
z.must_wait("the visitor to report a failure", 60, lambda: z.visitor_failing(NS),
            "The visitor never reported a failure. Run cleanup.py and try again.")
z.scene_set()
