#!/usr/bin/env python3
"""S5.4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-11-bad-rollout"
PODS = ["get", "pods", "-n", NS, "-l", "app=showdown", "-o"]


def stuck():
    # Stuck state: a new Pod is in CrashLoopBackOff while the 3 old Pods are still Ready.
    # (kubectl rollout status would just block here, so we read the Pods instead.)
    waiting = z.kubectl_out(*PODS, 'jsonpath={range .items[*]}{.status.containerStatuses[0].state.waiting.reason}{"\\n"}{end}')
    ready = z.kubectl_out(*PODS, 'jsonpath={range .items[*]}{.status.containerStatuses[0].ready}{"\\n"}{end}')
    return waiting.count("CrashLoopBackOff") >= 1 and ready.splitlines().count("true") == 3


z.start_break(SCENARIO, [NS], port=9211)
if not z.create_showdown_configmap(NS):
    z.die("Could not create the ConfigMap showdown-code.")
z.say("Releasing v1 (3 replicas)…")
z.apply_dir(HERE)
if z.kubectl("rollout", "status", "deployment/showdown", "-n", NS, "--timeout=180s")[0] != 0:
    z.die("v1 didn't become Ready. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.say("🚀 Friday, 6 PM: shipping v2…")
if z.kubectl("apply", "-f", os.path.join(HERE, "v2") + os.sep)[0] != 0:
    z.die("kubectl apply of v2 failed. Is the cluster healthy?")
z.must_wait("the new Pod to start crashing while the 3 old Pods stay Ready", 180, stuck,
            "Expected a stuck rollout, but didn't see it. Run cleanup.py and try again.")
z.scene_set()
