#!/usr/bin/env python3
"""S4.x2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-43-van"


def refused():
    # The Deployment's ReplicaSet was refused by the Pod Security check ("ReplicaFailure").
    return z.kubectl_out("get", "rs", "-n", NS, "-l", "app=van", "-o",
                         'jsonpath={.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}') != ""


z.start_break(SCENARIO, [NS], port=9243)
if z.kubectl("label", "namespace", NS, "pod-security.kubernetes.io/enforce=baseline", "--overwrite")[0] != 0:
    z.die("Could not label the namespace.")
z.say("Setting the scene…")
z.apply_dir(HERE)
z.must_wait("the ReplicaSet to be refused (the Deployment shows 0 Pods)", 90, refused,
            "The Pods were not refused as expected. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
