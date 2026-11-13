#!/usr/bin/env python3
"""S5.x4 fix: the safety rule now allows one Pod to be away at a time (minAvailable: 1 of 2).

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-39-idli-robot"


def one_allowed():
    allowed = z.kubectl_out("get", "pdb", "idli-pdb", "-n", NS, "-o", "jsonpath={.status.disruptionsAllowed}")
    return allowed.isdigit() and int(allowed) >= 1


z.need_cluster()
z.say("Loosening the safety rule: keep at least 1 of 2 Pods, not 2 of 2…")
z.apply_files(os.path.join(HERE, "pdb.yaml"))
z.must_wait("the rule to allow one Pod to move", 60, one_allowed,
            "The rule still allows nothing. Check: kubectl get pdb -n " + NS)
z.show_next("✅ Fixed. Send the robot in again:",
            "./evict.sh   ·   ./check.sh")
