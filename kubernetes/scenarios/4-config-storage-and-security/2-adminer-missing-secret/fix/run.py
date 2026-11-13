#!/usr/bin/env python3
"""S4.2 fix: create the missing Secret. The kubelet retries on its own, so the existing Pod starts.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-09-missing-secret"


def pod_ready():
    # NOT "rollout status": no new ReplicaSet is created, the SAME Pod just starts. Check the Pod itself.
    return z.kubectl_out("get", "pod", "-n", NS, "-l", "app=adminer", "-o",
                         "jsonpath={.items[0].status.containerStatuses[0].ready}") == "true"


z.need_cluster()
z.say("Creating the missing Secret adminer-db…")
z.apply_files(os.path.join(HERE, "secret.yaml"))
z.must_wait("the Adminer Pod to start by itself (the kubelet retries)", 180, pod_ready,
            "The Pod didn't become Ready. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods -n " + NS,
            z.forward_hint(NS, "adminer", 9209))
