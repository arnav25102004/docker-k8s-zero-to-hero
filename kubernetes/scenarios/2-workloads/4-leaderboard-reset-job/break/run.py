#!/usr/bin/env python3
"""S2.4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-28-job"


def redis_ready():
    return z.kubectl_out("get", "pod", "-n", NS, "-l", "app=redis", "-o",
                         "jsonpath={.items[0].status.containerStatuses[0].ready}") == "true"


def job_gave_up():
    # The intended failure: the Job has used up its retries.
    return z.kubectl_out("get", "job", "leaderboard-reset", "-n", NS, "-o",
                         'jsonpath={.status.conditions[?(@.type=="Failed")].status}') == "True"


z.start_break(SCENARIO, [NS])
z.say("Deploying Redis…")
z.apply_files(os.path.join(HERE, "redis.yaml"))
z.must_wait("Redis to start (the first download can take a minute)", 180, redis_ready,
            "Redis didn't start. Run cleanup.py and try again.")
z.say("Putting some scores on the leaderboard…")
if z.kubectl("exec", "-n", NS, "deploy/redis", "--", "redis-cli", "ZADD", "scores", "120", "Lakshmi", "95", "Ravi",
             "80", "Meera", "60", "Priya", "45", "Arjun")[0] != 0:
    z.die("Could not add the scores. Run cleanup.py and try again.")
z.say("Running the nightly reset Job…")
z.apply_files(os.path.join(HERE, "script.yaml"), os.path.join(HERE, "job.yaml"))
# Retries wait 10 s, then 20 s: about half a minute in all (longer if the Python image is still downloading).
z.must_wait("the Job to finish its attempts (about half a minute; the first download can take longer)", 180,
            job_gave_up, "The Job never finished. Run cleanup.py and try again.")
z.scene_set()
