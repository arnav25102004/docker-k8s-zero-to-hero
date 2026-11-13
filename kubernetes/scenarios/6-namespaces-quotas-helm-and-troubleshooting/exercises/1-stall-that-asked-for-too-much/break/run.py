#!/usr/bin/env python3
"""S6.x1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-40-limit-max"


def refused():
    # The Deployment's ReplicaSet was refused by the namespace's LimitRange ("ReplicaFailure").
    return z.kubectl_out("get", "rs", "-n", NS, "-l", "app=chaat", "-o",
                         'jsonpath={.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}') != ""


z.start_break(SCENARIO, [NS], port=9240)
z.say("Setting the scene…")
z.apply_dir(HERE)
z.must_wait("the ReplicaSet to be refused (the Deployment shows 0 Pods)", 90, refused,
            "The Pods were not refused as expected. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
