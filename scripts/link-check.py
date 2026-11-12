#!/usr/bin/env python3
"""Check every relative Markdown link (and #anchor) in the repo.
Usage: python3 scripts/link-check.py [repo-root]     Exit code 1 if anything is broken."""
import os, re, sys

root = sys.argv[1] if len(sys.argv) > 1 else "."

def slug(heading):
    # GitHub style: lowercase, drop punctuation (keep _ and -), spaces -> -
    h = re.sub(r"[`*]", "", heading.strip().lower())
    h = re.sub(r"[^\w\- ]", "", h, flags=re.U)
    return h.replace(" ", "-")

cache = {}
def anchors(path):
    if path not in cache:
        found, in_code = set(), False
        try:
            for line in open(path, encoding="utf-8"):
                if line.startswith("```"):
                    in_code = not in_code
                elif not in_code:
                    m = re.match(r"#{1,6}\s+(.*)", line)
                    if m:
                        found.add(slug(m.group(1)))
        except OSError:
            pass
        cache[path] = found
    return cache[path]

bad, total = [], 0
for d, _, files in os.walk(root):
    if ".git" in d.split(os.sep):
        continue
    for f in files:
        if not f.endswith(".md"):
            continue
        p, in_code = os.path.join(d, f), False
        for n, line in enumerate(open(p, encoding="utf-8"), 1):
            if line.startswith("```"):
                in_code = not in_code
                continue
            if in_code:
                continue
            for m in re.finditer(r"\]\(([^)\s]+)\)", line):
                t = m.group(1)
                if re.match(r"(https?:|mailto:)", t):
                    continue
                total += 1
                path, _, frag = t.partition("#")
                target = os.path.normpath(os.path.join(d, path)) if path else p
                if not os.path.exists(target):
                    bad.append((p, n, t, "file not found"))
                elif frag and target.endswith(".md") and frag not in anchors(target):
                    bad.append((p, n, t, "anchor not found"))

print(f"{total} relative links checked, {len(bad)} broken")
for b in bad:
    print("  %s:%d  %s  (%s)" % b)
sys.exit(1 if bad else 0)
