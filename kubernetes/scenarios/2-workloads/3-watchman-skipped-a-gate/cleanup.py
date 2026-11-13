#!/usr/bin/env python3
"""Removes everything scenario S2.3 created. Safe to run any time, any number of times."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))
import scenario_lib as z  # noqa: E402

z.cleanup_start()
# Remove the "reserved" sign first: if anything below were interrupted, the node must not stay reserved.
z.untaint_all("z2h-vip")
z.cleanup("k-16-daemonset")
