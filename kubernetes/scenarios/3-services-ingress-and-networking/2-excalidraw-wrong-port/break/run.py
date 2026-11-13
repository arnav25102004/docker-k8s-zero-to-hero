#!/usr/bin/env python3
"""S3.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-05-wrong-port"


def has_endpoints():
    # The intended failure: the Service has addresses, but nothing listens on the port it forwards to.
    return z.kubectl_out("get", "endpointslices", "-n", NS, "-l", "kubernetes.io/service-name=draw",
                         "-o", "jsonpath={..addresses}") != ""


def visitor_failing():
    return z.logs_contain(NS, "❌", "visitor", "--tail=3")


z.start_break(SCENARIO, [NS], port=9205)
z.say("Deploying Excalidraw (2 Pods), its Service and a visitor…")
z.apply_dir(HERE)
z.must_wait("the Excalidraw Pods to be Ready (the first download can take a minute)", 180,
            lambda: z.rolled_out(NS, "draw"), "The Pods didn't become Ready. Run cleanup.py and try again.")
z.wait_visitor(NS)
if not has_endpoints():
    z.die("Expected the Service to have endpoints, but it has none. Run cleanup.py and try again.")
z.must_wait("the visitor to report a failure", 60, visitor_failing,
            "The visitor never reported a failure. Run cleanup.py and try again.")
z.scene_set()
