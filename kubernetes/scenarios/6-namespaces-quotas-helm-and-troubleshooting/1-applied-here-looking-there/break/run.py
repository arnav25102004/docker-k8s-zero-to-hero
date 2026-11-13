#!/usr/bin/env python3
"""S6.1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-38-night-canteen"

z.start_break(SCENARIO, [NS], port=9238)
z.say("Deploying the night canteen (the manifest names its own namespace)…")
z.apply_dir(HERE)
z.must_wait("the night canteen to be Ready (the first download can take a minute)", 180,
            lambda: z.rolled_out(NS, "night-canteen"), "The Pods didn't become Ready. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
