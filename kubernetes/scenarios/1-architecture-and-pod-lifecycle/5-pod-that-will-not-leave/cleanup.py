#!/usr/bin/env python3
"""Removes everything scenario S1.5 created. Safe to run any time, any number of times."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))
import scenario_lib as z  # noqa: E402

z.cleanup_start()
# A finalizer keeps a Pod (and its namespace) from being deleted, so lift it first.
z.kubectl("patch", "pod", "old-stall", "-n", "k-37-stuck-pod", "--type", "merge", "-p", '{"metadata":{"finalizers":null}}')
z.cleanup("k-37-stuck-pod")
