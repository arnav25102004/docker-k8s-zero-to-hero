#!/usr/bin/env python3
"""S3.2 fix: the Service now forwards to targetPort 80, the port Excalidraw really listens on.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-05-wrong-port"


def port_is_80():
    # The endpointslice must now list port 80 (it listed 8080 while broken).
    return z.kubectl_out("get", "endpointslices", "-n", NS, "-l", "kubernetes.io/service-name=draw",
                         "-o", "jsonpath={..ports[*].port}") == "80"


z.need_cluster()
z.say("Pointing the Service at the right container port (targetPort 8080 → 80)…")
# A Service's targetPort can be changed in place, so a plain apply is enough.
z.apply_dir(HERE)
z.must_wait("the Excalidraw Deployment to be Ready", 180, lambda: z.rolled_out(NS, "draw"),
            "The Pods didn't become Ready. Check: kubectl get pods -n " + NS)
z.must_wait("the Service to forward to port 80", 60, port_is_80,
            "The Service still forwards to the wrong port. Check: kubectl get endpointslices -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get endpointslices -n %s -l kubernetes.io/service-name=draw" % NS,
            z.forward_hint(NS, "draw", 9205))
