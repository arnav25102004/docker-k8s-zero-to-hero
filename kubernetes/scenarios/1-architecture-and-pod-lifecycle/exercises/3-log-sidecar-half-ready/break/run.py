#!/usr/bin/env python3
"""S1.x3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-29-sidecar"


def half_ready():
    # The intended state: one container of the notice Pod is ready and the other is running but not ready.
    ready = z.kubectl_out("get", "pods", "-n", NS, "-l", "app=notice", "-o",
                          'jsonpath={range .items[0].status.containerStatuses[*]}{.ready}{" "}{end}').split()
    return "true" in ready and "false" in ready


z.start_break(SCENARIO, [NS], port=9229)
z.say("Deploying the Hostel Notice Board (one Pod, two containers), its Service and a visitor…")
z.apply_dir(HERE)
z.must_wait("the visitor to start (the first download can take a minute)", 180, lambda: z.visitor_running(NS),
            "The visitor Pod didn't start. Run cleanup.py and try again.")
z.must_wait("the notice board Pod to settle (the first download can take a minute)", 180, half_ready,
            "The notice board Pod didn't settle. Run cleanup.py and try again.")
z.scene_set()
