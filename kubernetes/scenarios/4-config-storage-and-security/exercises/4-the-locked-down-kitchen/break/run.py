#!/usr/bin/env python3
"""S4.x4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-45-lockdown"


def cfgerr():
    # The Pods were admitted by the Pod Security check, but their container could not be created.
    return "CreateContainerConfigError" in z.kubectl_out(
        "get", "pods", "-n", NS, "-l", "app=kitchen", "-o",
        "jsonpath={.items[*].status.containerStatuses[*].state.waiting.reason}")


z.start_break(SCENARIO, [NS], port=9245)
if z.kubectl("label", "namespace", NS, "pod-security.kubernetes.io/enforce=restricted", "--overwrite")[0] != 0:
    z.die("Could not label the namespace.")
z.say("Setting the scene…")
z.apply_dir(HERE)
z.must_wait("the Pods to be admitted and then stuck (the first download can take a minute)", 180, cfgerr,
            "The Pods did not get stuck as expected. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
