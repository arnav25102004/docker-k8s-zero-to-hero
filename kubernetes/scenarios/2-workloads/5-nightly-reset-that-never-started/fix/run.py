#!/usr/bin/env python3
"""S2.5 fix: the CronJob is no longer suspended; wait for the next run.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-24-cronjob"


def ran():
    return z.kubectl_out("get", "cronjob", "nightly-reset", "-n", NS, "-o", "jsonpath={.status.lastSuccessfulTime}") != ""


z.need_cluster()
z.say("Resuming the nightly reset…")
z.apply_files(os.path.join(HERE, "app.yaml"))
z.must_wait("the next scheduled minute to run the job (up to about 90 seconds)", 180, ran,
            "No run finished yet. Check: kubectl get cronjob,jobs -n " + NS)
z.show_next("✅ Fixed. Now check it yourself:",
            "./check.sh   ·   kubectl get jobs -n %s   ·   kubectl logs job/<one of the jobs> -n %s" % (NS, NS))
