#!/usr/bin/env python3
"""S4.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-09-missing-secret"

z.start_break(SCENARIO, [NS], port=9209)
z.say("Deploying Adminer, its Service and a visitor…")
z.apply_dir(HERE)
z.must_wait("the visitor to start (the first download can take a minute)", 180, lambda: z.visitor_running(NS),
            "The visitor Pod didn't start. Run cleanup.py and try again.")
# The intended failure: the container is stuck in CreateContainerConfigError.
z.must_wait("the Adminer Pod to get stuck on its missing Secret", 180,
            lambda: z.pod_reason(NS, "app=adminer") == "CreateContainerConfigError",
            "The Pod never reached CreateContainerConfigError. Run cleanup.py and try again.")
z.must_wait("the visitor to report a failure", 60, lambda: z.visitor_failing(NS),
            "The visitor never reported a failure. Run cleanup.py and try again.")
z.scene_set()
