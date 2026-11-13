#!/usr/bin/env python3
"""S2.5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-24-cronjob"

z.start_break(SCENARIO, [NS])
z.say("Scheduling the nightly reset…")
z.apply_dir(HERE)
z.must_wait("the CronJob to exist", 60, lambda: z.kubectl_ok("get", "cronjob", "nightly-reset", "-n", NS),
            "The CronJob was not created. Run cleanup.py and try again.")
z.scene_set()
