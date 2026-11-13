#!/usr/bin/env python3
"""S6.x2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-42-qos"


def all_running():
    return all(z.kubectl_out("get", "pods", "-n", NS, "-l", "app=" + name, "-o",
                             "jsonpath={.items[0].status.phase}") == "Running"
               for name in ("cache", "web", "batch"))


z.start_break(SCENARIO, [NS])
z.say("Setting the scene…")
z.apply_dir(HERE)
z.must_wait("the three workloads to be Running (the first download can take a minute)", 180, all_running,
            "The Pods did not start. Run cleanup.py and try again.")
z.scene_set()
