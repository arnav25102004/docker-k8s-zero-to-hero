#!/usr/bin/env python3
"""S5.x5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-41-hpa-target"
ABLE = 'jsonpath={.status.conditions[?(@.type=="AbleToScale")].status}'

z.start_break(SCENARIO, [NS], port=9241)
z.say("Setting the scene…")
z.apply_dir(HERE)
z.must_wait("the stall to be Ready (the first download can take a minute)", 180,
            lambda: z.rolled_out(NS, "lassi"), "The Pod didn't become Ready. Run cleanup.py and try again.")
z.must_wait("the autoscaler to report a problem (it syncs every 15 s)", 120,
            lambda: z.kubectl_out("get", "hpa", "lassi", "-n", NS, "-o", ABLE) == "False",
            "The autoscaler did not report a problem. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
