#!/usr/bin/env python3
"""S2.3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-16-daemonset"


def scene_ready():
    return z.kubectl_out("get", "daemonset", "watchman", "-n", NS, "-o", "jsonpath={.status.desiredNumberScheduled}") != ""


z.need_cluster()
z.run_cleanup(SCENARIO)
if not z.fresh_ns(NS):
    z.die("Could not create the namespace %s." % NS)
# Hang a "reserved" sign (a taint) on ONE gate (node), the last one in the list. cleanup.py removes it.
all_nodes = z.kubectl_out("get", "nodes", "-o", "name").splitlines()
if not all_nodes:
    z.die("Could not list the nodes. Check: kubectl get nodes")
node = all_nodes[-1].replace("node/", "", 1)
z.say("Reserving one node with a taint (cleanup.py removes it): %s…" % node)
if z.kubectl("taint", "nodes", node, "z2h-vip=true:NoSchedule", "--overwrite")[0] != 0:
    z.die("Could not taint the node.")
z.say("Posting a watchman at every gate…")
z.apply_dir(HERE)
z.must_wait("the DaemonSet to count its gates", 120, scene_ready,
            "The DaemonSet did not report. Run cleanup.py and try again.")
time.sleep(5)
z.scene_set()
