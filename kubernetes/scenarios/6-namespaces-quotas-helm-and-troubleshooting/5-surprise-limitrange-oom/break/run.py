#!/usr/bin/env python3
"""S6.5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-20-limitrange"
APP = ["get", "pods", "-n", NS, "-l", "app=showdown", "-o"]


def killed():
    # Wait until Kubernetes has recorded a kill (OOMKilled, or Error with exit 137 on some runtimes) for the app.
    reasons = z.kubectl_out(*APP, r'jsonpath={range .items[*]}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}')
    codes = z.kubectl_out(*APP, r'jsonpath={range .items[*]}{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}{end}')
    return "OOMKilled" in reasons or "137" in codes


z.start_break(SCENARIO, [NS], port=9220)
if not z.create_showdown_configmap(NS):
    z.die("Could not create the ConfigMap showdown-code.")
z.say("Deploying the Cats vs Dogs app and a visitor…")
# Namespace settings first: they only affect Pods created after they exist.
z.apply_files(os.path.join(HERE, "limitrange.yaml"))
z.apply_files(os.path.join(HERE, "app.yaml"), os.path.join(HERE, "visitor.yaml"))
z.must_wait("the app Pods to start misbehaving", 180, killed,
            "Expected the app to start crashing, but it didn't. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
