#!/usr/bin/env python3
"""S3.4 fix: the /dosa route points at the Service that really exists.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-33-gateway"


def resolved():
    return z.kubectl_out("get", "httproute", "menu", "-n", NS, "-o",
                         'jsonpath={.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}') == "True"


z.need_cluster()
z.say("Correcting the name of the dosa Service in the route…")
z.apply_files(os.path.join(HERE, "app.yaml"))
z.must_wait("the route to resolve", 120, resolved,
            "The route still does not resolve. Check: kubectl describe httproute menu -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl logs visitor -n %s --tail=3" % NS)
