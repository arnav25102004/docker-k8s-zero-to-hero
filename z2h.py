#!/usr/bin/env python3
"""Run any scenario with one short command. Needs only Python 3 (no packages) and bash.

    python3 z2h.py list                  all Kubernetes scenarios, by section
    python3 z2h.py list docker           the Docker scenarios
    python3 z2h.py break  S1.2           set the scene (same as: cd break && ./break.sh)
    python3 z2h.py check  S1.2           "am I done?"  (read-only)
    python3 z2h.py fix    S1.2           apply the fix
    python3 z2h.py cleanup S1.2          remove everything the scenario created
    python3 z2h.py test   S1.2           run the automated break/fix test (throwaway cluster only)

Ids: S1.2 = Kubernetes section 1, scenario 2 (S1.x1 = exercise 1). D02 = Docker scenario 2.
The scenario scripts themselves are bash; this file only finds the right one and runs it,
so you never have to remember a folder path. On Windows, use Git Bash or WSL.
"""
import csv
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
K8S = os.path.join(ROOT, "kubernetes", "scenarios")
DOCKER = os.path.join(ROOT, "docker", "scenarios")

# action -> (sub-folder, script name)
SCRIPTS = {
    "break": ("break", "break.sh"),
    "fix": ("fix", "fix.sh"),
    "check": ("", "check.sh"),
    "cleanup": ("", "cleanup.sh"),
}


def find_bash():
    bash = shutil.which("bash")
    if not bash:
        sys.exit("bash was not found. On Windows, open Git Bash (or WSL) and run this again.")
    return bash


def k8s_rows():
    """Every Kubernetes scenario: (id, folder, kind, title), read from index.tsv."""
    with open(os.path.join(K8S, "index.tsv"), encoding="utf-8", newline="") as f:
        reader = csv.reader(f, delimiter="\t")
        next(reader)  # header
        return [(r[0], os.path.join(K8S, r[2]), r[3], r[4]) for r in reader]


def docker_rows():
    rows = []
    for name in sorted(os.listdir(DOCKER)):
        path = os.path.join(DOCKER, name)
        if os.path.isdir(path) and name[:2].isdigit():
            title = name[3:].replace("-", " ")
            try:
                with open(os.path.join(path, "README.md"), encoding="utf-8") as f:
                    title = f.readline().lstrip("# ").strip()
                    title = title.split("·", 1)[-1].strip()
            except OSError:
                pass
            rows.append(("D" + name[:2], path, "core", title))
    return rows


def find(scenario_id):
    """Turn what the user typed (S2.3, 2.3, s2.3, D02, 2) into (id, folder, kind)."""
    wanted = scenario_id.strip().upper()
    if wanted.isdigit() and len(wanted) <= 2:
        wanted = "D" + wanted.zfill(2)
    elif wanted[:1].isdigit():
        wanted = "S" + wanted
    for sid, folder, kind, _title in k8s_rows() + docker_rows():
        if sid.upper() == wanted:
            return sid, folder, kind
    sys.exit("No scenario called '%s'. Try:  python3 z2h.py list" % scenario_id)


def show_list(which):
    if which == "docker":
        for sid, _folder, _kind, title in docker_rows():
            print("  %-4s %s" % (sid, title))
        return
    section = ""
    for sid, folder, kind, title in k8s_rows():
        head = os.path.relpath(folder, K8S).split(os.sep)[0]
        if head != section:
            section = head
            num, _, name = section.partition("-")
            print("\nSection %s: %s" % (num, name.replace("-", " ")))
        label = "  (exercise)" if "exercises" in folder else ""
        print("  %-7s %s%s" % (sid, title, label))


def run(action, scenario_id):
    sid, folder, kind = find(scenario_id)
    if kind == "question" and action != "cleanup":
        sys.exit("%s is a question exercise: there is no script to run.\nOpen %s and follow the steps."
                 % (sid, os.path.join(folder, "README.md")))
    sub, script = SCRIPTS[action]
    path = os.path.join(folder, sub, script)
    if not os.path.exists(path):
        sys.exit("%s has no %s script." % (sid, action))
    # Like the README says: break.sh runs from break/, fix.sh from fix/.
    return subprocess.call([find_bash(), path], cwd=os.path.dirname(path))


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    action = argv[1]
    if action == "list":
        show_list(argv[2] if len(argv) > 2 else "k8s")
        return 0
    if len(argv) < 3:
        sys.exit("Which scenario? Example:  python3 z2h.py %s S1.2" % action)
    if action == "test":
        sid, _folder, _kind = find(argv[2])
        return subprocess.call([find_bash(), os.path.join(ROOT, "tests", "scenarios", "k8s.sh"), sid])
    if action in SCRIPTS:
        return run(action, argv[2])
    sys.exit("Unknown command '%s'. Run:  python3 z2h.py help" % action)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
