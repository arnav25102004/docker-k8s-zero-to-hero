#!/usr/bin/env python3
"""Removes everything scenario S1.3 created. Safe to run any time, any number of times."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))
import scenario_lib as z  # noqa: E402

z.cleanup_start()
z.cleanup("k-03-crashloop")
