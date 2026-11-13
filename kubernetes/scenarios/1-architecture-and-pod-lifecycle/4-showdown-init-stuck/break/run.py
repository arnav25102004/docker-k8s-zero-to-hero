#!/usr/bin/env python3
"""S1.4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-26-init-stuck"
POD = ["get", "pod", "-n", NS, "-l"]


def redis_ready():
    return z.kubectl_out(*POD, "app=redis", "-o", "jsonpath={.items[0].status.containerStatuses[0].ready}") == "true"


def settled():
    # Settled = the app Pod is Pending (never became Ready) and its init container has been busy for a few seconds.
    # (Reads the Pod's own start state; no log lines are matched here.)
    if z.kubectl_out(*POD, "app=showdown", "-o", "jsonpath={.items[0].status.phase}") != "Pending":
        return False
    started = z.kubectl_out(*POD, "app=showdown", "-o",
                            "jsonpath={.items[0].status.initContainerStatuses[0].state.running.startedAt}")
    if started == "":
        return False
    return z.kubectl_out("logs", "-n", NS, "-l", "app=showdown", "-c", "wait-for-redis") != ""


z.start_break(SCENARIO, [NS], port=9226)
if not z.create_showdown_configmap(NS):
    z.die("Could not create the ConfigMap showdown-code.")
z.say("Deploying Redis, the Cats vs Dogs app and a visitor…")
z.apply_dir(HERE)
z.must_wait("Redis to start (the first download can take a minute)", 180, redis_ready,
            "Redis didn't start. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.must_wait("the app Pod to settle", 180, settled,
            "The app Pod didn't settle into its failing state. Run cleanup.py and try again.")
z.scene_set()
