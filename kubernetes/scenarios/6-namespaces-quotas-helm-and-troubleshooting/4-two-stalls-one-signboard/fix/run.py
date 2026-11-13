#!/usr/bin/env python3
"""S6.4 fix: the Service now asks for app: chai AND track: fresh, so only the fresh stall matches.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-31-two-stalls"
TARGETS = r'jsonpath={range .items[*].endpoints[*]}{.targetRef.name}{"\n"}{end}'


def only_fresh():
    out = z.kubectl_out("get", "endpointslices", "-n", NS, "-l", "kubernetes.io/service-name=chai", "-o", TARGETS)
    return not any(line.startswith("stale-chai-") for line in out.splitlines())


z.need_cluster()
z.say("Making the Service selector more precise (app: chai + track: fresh)…")
z.apply_files(os.path.join(HERE, "service.yaml"))
z.must_wait("the Service to stop sending customers to the stale stall", 60, only_fresh,
            "The stale stall is still behind the Service. Check: kubectl get endpointslices -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "kubectl logs visitor -n k-31-two-stalls --tail=5   (only fresh chai now)   ·   ./check.sh")
