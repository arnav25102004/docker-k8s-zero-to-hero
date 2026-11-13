#!/usr/bin/env python3
"""S1.3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-03-crashloop"


def looping():
    # First the Pod crashes and restarts; after a couple of crashes the kubelet reports CrashLoopBackOff.
    # We also wait for the crash message of the dead container to exist.
    return (z.pod_reason(NS, "app=showdown") == "CrashLoopBackOff"
            and z.logs_contain(NS, "ValueError", "-l", "app=showdown", "--previous"))


z.start_break(SCENARIO, [NS], port=9203)
if not z.create_showdown_configmap(NS):
    z.die("Could not create the ConfigMap showdown-code.")
z.say("Deploying the Cats vs Dogs app and a visitor…")
z.apply_dir(HERE)
z.must_wait("the app to start crashing (CrashLoopBackOff)", 180, looping,
            "Expected a crash loop, but didn't see it. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
