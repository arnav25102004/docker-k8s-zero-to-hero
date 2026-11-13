#!/usr/bin/env python3
"""S3.5 fix: add the missing DNS rule to the lockdown policy (a policy can be changed in place).

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-13-lockdown"

z.need_cluster()
z.say("Letting the app talk to DNS (port 53 in kube-system)…")
z.apply_files(os.path.join(HERE, "app.yaml"))
z.say("Checking the app rolled out…")
if z.kubectl("rollout", "status", "deployment/showdown", "-n", NS, "--timeout=180s")[0] != 0:
    z.die("The app didn't roll out. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get networkpolicy lockdown -n %s -o yaml" % NS,
            z.forward_hint(NS, "showdown", 9213))
