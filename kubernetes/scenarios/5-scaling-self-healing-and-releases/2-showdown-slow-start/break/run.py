#!/usr/bin/env python3
"""S5.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-07-slow-start"


def killed_twice():
    # The kubelet kills the container on the first failed liveness check, over and over.
    # We wait for two restarts and for the app's "slow startup" log line to exist.
    restarts = z.kubectl_out("get", "pod", "-n", NS, "-l", "app=showdown", "-o",
                             "jsonpath={.items[0].status.containerStatuses[0].restartCount}")
    if not restarts.isdigit() or int(restarts) < 2:
        return False
    return z.logs_contain(NS, "simulating slow startup", "-l", "app=showdown", "--previous")


z.start_break(SCENARIO, [NS], port=9207)
if not z.create_showdown_configmap(NS):
    z.die("Could not create the ConfigMap showdown-code.")
z.say("Deploying the Cats vs Dogs app and a visitor…")
z.apply_dir(HERE)
z.must_wait("the app to be killed and restarted twice", 180, killed_twice,
            "Expected repeated restarts, but didn't see them. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
