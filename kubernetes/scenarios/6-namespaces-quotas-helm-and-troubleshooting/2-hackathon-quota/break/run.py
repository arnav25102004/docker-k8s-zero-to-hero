#!/usr/bin/env python3
"""S6.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-19-hackathon"


def quota_live():
    # The quota must be "live" (its totals filled in) before any Pod is created, otherwise the
    # first Pods could slip in without being counted.
    return z.kubectl_out("get", "resourcequota", "hackathon-quota", "-n", NS, "-o",
                         r"jsonpath={.status.hard.requests\.cpu}") != ""


z.start_break(SCENARIO, [NS], port=9219)
z.say("Setting up the hackathon namespace…")
z.apply_files(os.path.join(HERE, "setup.yaml"))
z.must_wait("the namespace setup to finish", 60, quota_live,
            "The namespace setup didn't finish. Run cleanup.py and try again.")
z.say("Deploying the hackathon dashboard and a visitor…")
z.apply_dir(HERE)
# The intended failure: the ReplicaSet's events say it was refused by the quota.
z.must_wait("the dashboard to misbehave", 180, lambda: z.events_contain(NS, "failed quota"),
            "Expected the dashboard to fail, but didn't see it. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
