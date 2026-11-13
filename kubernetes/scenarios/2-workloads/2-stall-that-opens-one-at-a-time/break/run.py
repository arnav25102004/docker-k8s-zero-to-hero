#!/usr/bin/env python3
"""S2.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-15-statefulset"

z.start_break(SCENARIO, [NS])
z.say("Setting the scene…")
z.apply_dir(HERE)
z.must_wait("the first stall (stall-0) to start (the first download can take a minute)", 180,
            lambda: z.pod_phase(NS, "stall-0") == "Running", "stall-0 did not start. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
