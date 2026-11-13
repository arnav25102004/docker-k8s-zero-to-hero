#!/usr/bin/env python3
"""S5.5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-08-oomkilled"


def killed():
    # We wait until Kubernetes has recorded a kill (lastState) AND the previous run's log exists.
    reason = z.kubectl_out("get", "pod", "-n", NS, "-l", "app=trainer", "-o",
                           "jsonpath={.items[0].status.containerStatuses[0].lastState.terminated.reason}")
    return reason != "" and z.logs_contain(NS, "epoch 3/6", "-l", "app=trainer", "--previous")


z.start_break(SCENARIO, [NS])
z.say("Starting the AI trainer with a 64Mi memory limit…")
z.apply_dir(HERE)
z.must_wait("the trainer to be killed", 180, killed,
            "Expected the trainer to be killed, but it wasn't. Run cleanup.py and try again.")
z.scene_set()
