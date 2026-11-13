#!/usr/bin/env python3
"""S4.4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-14-forbidden"

z.start_break(SCENARIO, [NS])
z.say("Deploying the leaderboard bot and two players…")
z.apply_files(os.path.join(HERE, "app.yaml"))
z.must_wait("the players to start", 180, lambda: z.rolled_out(NS, "players"),
            "The players didn't start. Run cleanup.py and try again.")
# The bot has asked the API at least once and been told 403.
z.must_wait("the bot to be refused by the API (403)", 180, lambda: z.logs_contain(NS, "403", "bot"),
            "Expected the bot to be refused, but didn't see it. Run cleanup.py and try again.")
z.scene_set()
