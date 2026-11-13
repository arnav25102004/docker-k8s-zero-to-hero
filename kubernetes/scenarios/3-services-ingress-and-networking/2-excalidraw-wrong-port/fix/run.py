#!/usr/bin/env python3
"""Applies the fix for this scenario. Run it from this folder:  python3 run.py

It just runs fix.sh next to it (bash is needed; on Windows use Git Bash or WSL)."""
import os
import shutil
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
bash = shutil.which("bash")
if not bash:
    sys.exit("bash was not found. On Windows, open Git Bash (or WSL) and try again.")
sys.exit(subprocess.call([bash, os.path.join(here, "fix.sh")], cwd=here))
