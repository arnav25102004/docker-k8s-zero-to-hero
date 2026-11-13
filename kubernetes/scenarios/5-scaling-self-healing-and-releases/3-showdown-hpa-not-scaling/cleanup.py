#!/usr/bin/env python3
"""Removes everything scenario S5.3 created. Safe to run any time, any number of times."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))
import scenario_lib as z  # noqa: E402

z.cleanup_start()
z.cleanup("k-25-hpa")
# Namespace first, then the add-on, so an interrupted run never leaves either behind.
z.remove_metrics_server_if_ours("k25")
