#!/usr/bin/env python3
"""S5.x4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-39-idli-robot"


def budget_ready():
    return z.kubectl_out("get", "pdb", "idli-pdb", "-n", NS, "-o", "jsonpath={.status.currentHealthy}") == "2"


z.start_break(SCENARIO, [NS], port=9239)
z.say("Opening the idli stall (two Pods) and a safety rule…")
z.apply_dir(HERE)
z.must_wait("the idli stall to be Ready (the first download can take a minute)", 180,
            lambda: z.rolled_out(NS, "idli"), "The Pods didn't become Ready. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.must_wait("the safety rule to count both Pods", 60, budget_ready,
            "The safety rule did not settle. Run cleanup.py and try again.")
z.scene_set()
