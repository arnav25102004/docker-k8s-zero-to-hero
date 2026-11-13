#!/usr/bin/env python3
"""S3.1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-04-no-endpoints"


def no_endpoints():
    # The intended failure: the Pods are Ready, yet the Service has no addresses.
    return z.kubectl_out("get", "endpointslices", "-n", NS, "-l", "kubernetes.io/service-name=tools",
                         "-o", "jsonpath={..addresses}") == ""


z.start_break(SCENARIO, [NS], port=9204)
z.say("Deploying IT-Tools (2 Pods), its Service and a visitor…")
z.apply_dir(HERE)
z.must_wait("the IT-Tools Pods to be Ready (the first download can take a minute)", 180,
            lambda: z.rolled_out(NS, "tools"), "The Pods didn't become Ready. Run cleanup.py and try again.")
z.wait_visitor(NS)
if not no_endpoints():
    z.die("Expected a Service with no endpoints, but it has some. Run cleanup.py and try again.")
z.scene_set()
