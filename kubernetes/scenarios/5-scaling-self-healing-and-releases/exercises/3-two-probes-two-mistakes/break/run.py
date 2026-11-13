#!/usr/bin/env python3
"""S5.x3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-36-two-probes"

z.start_break(SCENARIO, [NS], port=9236)
z.say("Opening the stall and sending in a visitor…")
z.apply_dir(HERE)
z.must_wait("the stall's Pods to be created (the first download can take a minute)", 180,
            lambda: z.pods_exist(NS, "app=thali"), "The Pods were not created. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
