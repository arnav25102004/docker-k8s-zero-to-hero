#!/usr/bin/env python3
"""S6.x5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-30-friday"


def app_ready():
    ready = z.kubectl_out("get", "pods", "-n", NS, "-l", "app=showdown", "-o",
                          r'jsonpath={range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}')
    return ready.splitlines().count("true") == 2


def db_settled():
    return z.pod_reason(NS, "app=redis") in ("ImagePullBackOff", "ErrImagePull")


z.start_break(SCENARIO, [NS], port=9230)
if not z.create_showdown_configmap(NS):
    z.die("Could not create the ConfigMap showdown-code.")
z.say("Shipping the Friday release: the Cats vs Dogs app, its database, its Service and a visitor…")
z.apply_dir(HERE)
z.must_wait("the app Pods to start (the first download can take a minute)", 180, app_ready,
            "The app Pods didn't start. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.must_wait("the database Pod to settle", 180, db_settled,
            "The database Pod didn't settle into its failing state. Run cleanup.py and try again.")
z.scene_set()
