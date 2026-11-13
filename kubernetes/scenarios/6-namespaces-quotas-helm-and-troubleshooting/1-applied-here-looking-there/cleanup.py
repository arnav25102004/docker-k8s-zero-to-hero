#!/usr/bin/env python3
"""Removes everything scenario S6.1 created. Safe to run any time, any number of times."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))
import scenario_lib as z  # noqa: E402

z.cleanup_start()
# Put your context's namespace back only if this scenario was the one that changed it.
if z.kubectl_out("config", "view", "--minify", "-o", "jsonpath={..namespace}") == "k-38-night-canteen":
    z.kubectl("config", "set-context", "--current", "--namespace=")
z.cleanup("k-38-night-canteen")
