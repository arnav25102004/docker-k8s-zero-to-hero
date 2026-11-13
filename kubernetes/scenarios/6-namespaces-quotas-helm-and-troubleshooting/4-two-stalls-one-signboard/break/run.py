#!/usr/bin/env python3
"""S6.4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-31-two-stalls"
TARGETS = r'jsonpath={range .items[*].endpoints[*]}{.targetRef.name}{"\n"}{end}'


def both_stalls_ready():
    return z.rolled_out(NS, "chai") and z.rolled_out(NS, "stale-chai")


def all_pods_behind_service():
    out = z.kubectl_out("get", "endpointslices", "-n", NS, "-l", "kubernetes.io/service-name=chai", "-o", TARGETS)
    return len([line for line in out.splitlines() if line.strip()]) == 3


z.start_break(SCENARIO, [NS], port=9231)
z.say("Opening the stall(s) and sending in a visitor…")
z.apply_dir(HERE)
z.must_wait("the stall(s) to be Ready (the first download can take a minute)", 180, both_stalls_ready,
            "The Pods didn't become Ready. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.must_wait("the Service to pick up all three Pods", 60, all_pods_behind_service,
            "The Service did not pick up all three Pods in time. Run cleanup.py and try again.")
z.scene_set()
