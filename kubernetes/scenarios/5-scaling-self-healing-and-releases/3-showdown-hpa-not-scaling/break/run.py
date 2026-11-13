#!/usr/bin/env python3
"""S5.3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-25-hpa"
CONDITION = 'jsonpath={.status.conditions[?(@.type=="ScalingActive")].%s}'


def hpa_cannot_read():
    # The autoscaler has tried at least once and reported that it could not compute a CPU reading
    # (not just "no metrics yet", which the first few seconds always say).
    reason = z.kubectl_out("get", "hpa", "showdown", "-n", NS, "-o", CONDITION % "reason")
    message = z.kubectl_out("get", "hpa", "showdown", "-n", NS, "-o", CONDITION % "message")
    if reason != "FailedGetResourceMetric":
        return False
    return "did not receive metrics" not in message and "no metrics returned" not in message


z.start_break(SCENARIO, [NS], port=9225)
z.say("Making sure the cluster can measure CPU (installing metrics-server if it is not there; this can take a minute)…")
if not z.ensure_metrics_server("k25"):
    z.die("metrics-server did not become ready. Check: kubectl -n kube-system get pods")
if not z.create_showdown_configmap(NS):
    z.die("Could not create the ConfigMap showdown-code.")
z.say("Deploying the Cats vs Dogs app, an autoscaler and some traffic…")
z.apply_files(os.path.join(HERE, "app.yaml"), os.path.join(HERE, "hpa.yaml"), os.path.join(HERE, "load.yaml"))
z.must_wait("the load to start", 180, lambda: z.pod_phase(NS, "load") == "Running",
            "The load Pod didn't start. Run cleanup.py and try again.")
z.must_wait("the autoscaler to report its first reading", 180, hpa_cannot_read,
            "The autoscaler never reported. Run cleanup.py and try again.")
z.scene_set()
