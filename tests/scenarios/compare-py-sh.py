#!/usr/bin/env python3
"""Offline check that every scenario's run.py / cleanup.py does what its .sh twin does.

No cluster needed. A fake `kubectl` answers every call and writes down what it was asked.
Each scenario is run twice (bash script, then Python script) and the two lists of kubectl
commands must be identical.

    python3 tests/scenarios/compare-py-sh.py            # every scenario
    python3 tests/scenarios/compare-py-sh.py S1.2 S3.4  # just these
"""
import csv
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SC = os.path.join(ROOT, "kubernetes", "scenarios")

FAKE = r'''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
if os.path.basename(sys.argv[0]) == "helm":
    args = ["helm"] + args
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write(json.dumps(args) + "\n")
text = " ".join(args)
if "wget" in args and "-T" in args and args[args.index("-T") + 1] == "1":
    sys.exit(1)                       # pretend the NetworkPolicy is enforced
if args[:2] == ["get", "namespace"]:
    sys.exit(1)                       # "not found": nothing to wait for
if args[:2] == ["get", "nodes"] and "name" in args:
    print("node/n1\nnode/n2")
if "jsonpath" in text and "U=" in text:   # node list used to count schedulable nodes
    print("n1 U= \nn2 U= \nn3 U= |NoSchedule|")
sys.exit(0)
'''


def rows():
    with open(os.path.join(SC, "index.tsv"), encoding="utf-8", newline="") as f:
        r = csv.reader(f, delimiter="\t")
        next(r)
        return [x for x in r if x[3] != "question"]


def normal(args):
    """Same command, spelled the same way: the path quirk, and `-n NAMESPACE` always last."""
    args = [a.replace("/kubernetes/scenarios/../../", "/") for a in args]
    args = [os.path.normpath(a) if a.startswith("/") and "/../" in a else a for a in args]
    if "-n" in args and args.index("-n") + 1 < len(args):
        i = args.index("-n")
        args = args[:i] + args[i + 2:] + ["-n", args[i + 1]]
    return args


def run(cmd, env, cwd):
    open(env["FAKE_LOG"], "w").close()
    subprocess.run(cmd, env=env, cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    with open(env["FAKE_LOG"]) as f:
        return [normal(json.loads(line)) for line in f if line.strip()]


def main(argv):
    wanted = {a.upper().lstrip("S") for a in argv[1:]}
    tmp = tempfile.mkdtemp(prefix="z2h-fake-")
    try:
        for tool in ("kubectl", "helm"):
            fake = os.path.join(tmp, tool)
            with open(fake, "w") as f:
                f.write(FAKE)
            os.chmod(fake, 0o755)
        env = dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"], FAKE_LOG=os.path.join(tmp, "log"),
                   Z2H_CHECK_ONCE="1", Z2H_MS_WAIT="2")
        bad = checked = 0
        for sid, _legacy, rel, _kind, _title in rows():
            if wanted and sid.upper().lstrip("S") not in wanted:
                continue
            base = os.path.join(SC, rel)
            for name, sh, py in (("break", "break/break.sh", "break/run.py"),
                                 ("fix", "fix/fix.sh", "fix/run.py"),
                                 ("cleanup", "cleanup.sh", "cleanup.py")):
                if not os.path.exists(os.path.join(base, py)):
                    continue
                folder = os.path.dirname(os.path.join(base, sh))
                a = run(["bash", os.path.join(base, sh)], env, folder)
                b = run([sys.executable, os.path.join(base, py)], env, folder)
                checked += 1
                if a != b:
                    bad += 1
                    print("DIFFERENT  %s %s" % (sid, name))
                    for i in range(max(len(a), len(b))):
                        x = a[i] if i < len(a) else None
                        y = b[i] if i < len(b) else None
                        if x != y:
                            print("   first difference at call %d:\n     sh: %s\n     py: %s" % (i + 1, x, y))
                            break
        print("%d compared, %d different" % (checked, bad))
        return 1 if bad else 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
