#!/usr/bin/env python3
"""S1.1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-01-pending"


def stuck():
    # The scheduler refused the Pod: it is Pending, and an Event says why.
    return z.pod_reason(NS, "app=draw") == "Pending" and z.events_contain(NS, "Insufficient memory")


z.start_break(SCENARIO, [NS], port=9201)
z.say("Deploying the whiteboard (Excalidraw) and a visitor…")
z.apply_dir(HERE)
z.must_wait("the Pod to be refused by the scheduler", 180, stuck,
            "Expected a Pending Pod, but didn't see it. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
