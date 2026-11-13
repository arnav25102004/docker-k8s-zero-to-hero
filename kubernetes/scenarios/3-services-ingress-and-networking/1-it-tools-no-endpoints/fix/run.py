#!/usr/bin/env python3
"""S3.1 fix: the Service now selects tier: backend, the label the Pods really carry.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-04-no-endpoints"


def has_endpoints():
    return z.kubectl_out("get", "endpointslices", "-n", NS, "-l", "kubernetes.io/service-name=tools",
                         "-o", "jsonpath={..addresses}") != ""


z.need_cluster()
z.say("Pointing the Service at the right label (tier: frontend → tier: backend)…")
# A Service's selector can be changed in place, so a plain apply is enough.
z.apply_dir(HERE)
z.must_wait("the IT-Tools Deployment to be Ready", 180, lambda: z.rolled_out(NS, "tools"),
            "The Pods didn't become Ready. Check: kubectl get pods -n " + NS)
z.must_wait("the Service to find its Pods", 60, has_endpoints,
            "The Service still has no endpoints. Check: kubectl get endpointslices -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get endpointslices -n %s -l kubernetes.io/service-name=tools" % NS,
            z.forward_hint(NS, "tools", 9204))
