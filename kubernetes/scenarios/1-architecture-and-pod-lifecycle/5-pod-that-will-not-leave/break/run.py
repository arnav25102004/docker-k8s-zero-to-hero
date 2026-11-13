#!/usr/bin/env python3
"""S1.5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-37-stuck-pod"


def pod_running():
    return z.pod_phase(NS, "old-stall") == "Running"


def being_deleted():
    return z.kubectl_out("get", "pod", "old-stall", "-n", NS, "-o", "jsonpath={.metadata.deletionTimestamp}") != ""


z.start_break(SCENARIO, [NS])
z.say("Opening the old stall…")
z.apply_dir(HERE)
z.must_wait("the stall to be Running (the first download can take a minute)", 180, pod_running,
            "The Pod didn't start. Run cleanup.py and try again.")
z.say("Closing the old stall (kubectl delete pod old-stall)…")
if z.kubectl("delete", "pod", "old-stall", "-n", NS, "--wait=false")[0] != 0:
    z.die("kubectl delete failed.")
z.must_wait("the delete to be accepted", 30, being_deleted,
            "The Pod was not marked for deletion. Run cleanup.py and try again.")
z.scene_set()
