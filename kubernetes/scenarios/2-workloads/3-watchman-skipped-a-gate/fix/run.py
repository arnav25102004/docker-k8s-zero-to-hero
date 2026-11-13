#!/usr/bin/env python3
"""S2.3 fix: the watchman tolerates the reserved signs.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-16-daemonset"


def settled():
    nodes = len(z.kubectl_out("get", "nodes", "--no-headers").splitlines())
    want = z.kubectl_out("get", "daemonset", "watchman", "-n", NS, "-o", "jsonpath={.status.desiredNumberScheduled}") or "0"
    ready = z.kubectl_out("get", "daemonset", "watchman", "-n", NS, "-o", "jsonpath={.status.numberReady}") or "0"
    return want == str(nodes) and ready == str(nodes)


z.need_cluster()
z.say("Teaching the watchman to tolerate the reserved signs…")
z.apply_files(os.path.join(HERE, "app.yaml"))
z.must_wait("a watchman at every gate", 180, settled,
            "Not every gate has a watchman yet. Check: kubectl get daemonset,pods -n %s -o wide" % NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl get daemonset,pods -n %s -o wide" % NS)
