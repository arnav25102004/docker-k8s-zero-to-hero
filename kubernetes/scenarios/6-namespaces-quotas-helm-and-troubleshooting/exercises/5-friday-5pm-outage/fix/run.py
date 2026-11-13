#!/usr/bin/env python3
"""S6.x5 fix: applies the three fixes one at a time, in the README's order, waiting for each.

Run it from this folder:  python3 run.py"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-30-friday"
# Applies the three fixes one at a time, in the README's order, waiting for each.
# Idempotent: any fix already made by hand is simply applied again (no change), so it is
# safe to run after fixing one, two or all three tracks yourself.

z.need_cluster()
z.say("Fix 1 of 3 (Track A): Redis image tag redis:7.4.12-alpine…")
z.apply_files(os.path.join(HERE, "redis.yaml"))
if z.kubectl("rollout", "status", "deployment/redis", "-n", NS, "--timeout=180s")[0] != 0:
    z.die("Redis didn't roll out. Check: kubectl get pods -n " + NS)
z.say("Fix 2 of 3 (Track B): Service showdown targetPort 8080…")
z.apply_files(os.path.join(HERE, "service.yaml"))
z.say("Fix 3 of 3 (Track C): REDIS_HOST=redis for the app, new Pods roll out…")
z.apply_files(os.path.join(HERE, "app.yaml"))
# If REDIS_HOST was set by hand long before Redis was fixed, the stalled rollout may have
# passed its progress deadline; it resumes on its own now, so give rollout status a retry.
if z.kubectl("rollout", "status", "deployment/showdown", "-n", NS, "--timeout=180s")[0] != 0:
    time.sleep(5)
    if z.kubectl("rollout", "status", "deployment/showdown", "-n", NS, "--timeout=120s")[0] != 0:
        z.die("The app didn't roll out. Check: kubectl get pods -n " + NS)
# Old app Pods are removed shortly after the new ones are Ready: wait until only 2 are left.
z.must_wait("the old app Pods to be removed", 60, lambda: z.pod_count(NS, "app=showdown") == 2,
            "Old app Pods are still there. Check: kubectl get pods -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl logs visitor -n %s --tail=3" % NS,
            z.forward_hint(NS, "showdown", 9230))
