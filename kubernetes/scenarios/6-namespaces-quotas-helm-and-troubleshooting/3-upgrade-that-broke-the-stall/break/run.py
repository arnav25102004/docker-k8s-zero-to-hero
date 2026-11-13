#!/usr/bin/env python3
"""S6.3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-27-helm"
CHART = os.path.join(SCENARIO, "chart", "stall")


def bad_pod():
    reasons = z.kubectl_out("get", "pods", "-n", NS, "-l", "app=stall", "-o",
                            "jsonpath={.items[*].status.containerStatuses[*].state.waiting.reason}")
    return "ErrImagePull" in reasons or "ImagePullBackOff" in reasons


z.need_cluster()
z.need_helm()
z.run_cleanup(SCENARIO)
if not z.fresh_ns(NS):
    z.die("Could not create the namespace %s." % NS)
z.say("Installing the stall with Helm (revision 1)…")
if z.helm("install", "stall", CHART, "-n", NS, "--wait", "--timeout", "3m") != 0:
    z.die("helm install failed. Is the cluster healthy? (kubectl get pods -n %s)" % NS)
z.apply_files(os.path.join(HERE, "visitor.yaml"))
z.must_wait("the visitor to start", 180, lambda: z.visitor_running(NS),
            "The visitor Pod didn't start. Run cleanup.py and try again.")
z.say("Shipping an upgrade with Helm (revision 2)…")
if z.helm("upgrade", "stall", CHART, "-n", NS, "--set", "image.tag=9.9.9") != 0:
    z.die("helm upgrade failed. Run cleanup.py and try again.")
z.must_wait("the new Pod to fail its image pull", 120, bad_pod,
            "The upgrade did not break as expected. Run cleanup.py and try again.")
z.scene_set()
