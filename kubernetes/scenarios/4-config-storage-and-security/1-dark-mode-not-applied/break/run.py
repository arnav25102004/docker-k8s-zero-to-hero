#!/usr/bin/env python3
"""S4.1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-23-dark-mode"


def page_ready():
    return z.kubectl_out("get", "deployment", "theme", "-n", NS, "-o", "jsonpath={.status.readyReplicas}") == "1"


z.start_break(SCENARIO, [NS], port=9223)
z.say("Deploying the Campus Today page and a visitor…")
z.apply_files(os.path.join(HERE, "code.yaml"), os.path.join(HERE, "config.yaml"))
z.apply_files(os.path.join(HERE, "app.yaml"), os.path.join(HERE, "visitor.yaml"))
z.must_wait("the theme page to be ready", 180, page_ready,
            "The page didn't become ready. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.say("The design team switches dark mode on in the config…")
if z.kubectl("patch", "configmap", "ui-settings", "-n", NS, "--type", "merge", "-p", '{"data":{"THEME":"dark"}}')[0] != 0:
    z.die("Could not update the ConfigMap.")
z.scene_set()
