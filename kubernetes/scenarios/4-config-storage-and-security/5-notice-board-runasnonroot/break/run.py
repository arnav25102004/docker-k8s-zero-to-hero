#!/usr/bin/env python3
"""S4.5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-21-nonroot"

z.start_break(SCENARIO, [NS], port=9221)
z.say("Deploying the Campus notice board (2 Pods), its Service and a visitor…")
z.apply_dir(HERE)
z.must_wait("the visitor to start", 180, lambda: z.visitor_running(NS),
            "The visitor Pod didn't start. Run cleanup.py and try again.")
# The intended failure: the board Pods exist but their container was never created.
z.must_wait("the notice board Pods to settle", 180,
            lambda: z.pod_reason(NS, "app=board") == "CreateContainerConfigError",
            "The notice board Pods didn't settle. Run cleanup.py and try again.")
z.scene_set()
