#!/usr/bin/env python3
"""S2.4 fix: a Job's Pod template can't be edited after creation, so delete the Job and create it again.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-28-job"

z.need_cluster()
z.say("Deleting the failed Job (its Pod template is immutable) and creating it again…")
# Editing spec.template of an existing Job is refused by Kubernetes, so delete and re-create.
if z.kubectl("delete", "job", "leaderboard-reset", "-n", NS, "--ignore-not-found", "--wait=true")[0] != 0:
    z.die("Could not delete the Job.")
z.apply_files(os.path.join(HERE, "job.yaml"))
z.say("Waiting for the Job to complete…")
if z.kubectl("wait", "--for=condition=complete", "job/leaderboard-reset", "-n", NS, "--timeout=120s")[0] != 0:
    z.die("The Job didn't complete. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get job -n " + NS,
            "kubectl logs job/leaderboard-reset -n " + NS)
