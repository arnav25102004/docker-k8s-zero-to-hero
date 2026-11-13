#!/usr/bin/env python3
"""S4.4 fix: give the bot's ServiceAccount a Role (get, list on pods) through a RoleBinding.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-14-forbidden"


def bot_ok():
    # The bot's newest log line is a ✅ line (it runs every 5 s; no restart needed).
    return z.logs_contain(NS, "✅", "bot", "--tail=1")


z.need_cluster()
z.say("Granting the bot permission to read Pods (Role + RoleBinding)…")
z.apply_files(os.path.join(HERE, "rbac.yaml"))
z.must_wait("the bot to read the Pods (✅)", 60, bot_ok,
            "The bot still isn't succeeding. Check: kubectl logs bot -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl logs bot -n %s --tail=3" % NS,
            "kubectl auth can-i list pods -n %s --as=system:serviceaccount:%s:leaderboard-bot" % (NS, NS))
