#!/usr/bin/env python3
"""S1.x1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-17-needs-gpu"


def refused():
    # The intended failure: the Pod exists, the scheduler refused it, and an event says why.
    pods = z.kubectl_out("get", "pods", "-n", NS, "-l", "app=trainer", "--no-headers")
    return " Pending " in pods and z.events_contain(NS, "FailedScheduling")


z.start_break(SCENARIO, [NS])
z.say("Starting the AI trainer…")
z.apply_dir(HERE)
z.must_wait("the scheduler to refuse the trainer", 60, refused,
            "The trainer never showed up as Pending. Run cleanup.py and try again.")
z.scene_set()
