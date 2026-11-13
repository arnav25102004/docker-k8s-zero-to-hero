#!/usr/bin/env python3
"""S1.2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-02-image-typo"


def stuck():
    # The kubelet reports ErrImagePull right after a failed pull, then ImagePullBackOff while it waits to retry.
    # Either one is the intended failure; we also wait for the pull error to appear in the Events.
    return z.pod_reason(NS, "app=draw") in ("ErrImagePull", "ImagePullBackOff") and z.events_contain(NS, "pull")


z.start_break(SCENARIO, [NS], port=9202)
z.say("Deploying the whiteboard (Excalidraw) and a visitor…")
z.apply_dir(HERE)
z.must_wait("the image pull to fail", 180, stuck,
            "Expected an image pull failure, but didn't see it. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.scene_set()
