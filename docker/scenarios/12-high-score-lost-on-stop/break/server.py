"""Dosa Dash server: serves the game and a tiny high-score API. Python standard library only.

Scores live in memory. They are written to /data/scores.json ONLY when the
process receives SIGTERM (what `docker stop` sends), and read back at start-up.
"""
import json
import os
import signal
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
SCORES_FILE = "/data/scores.json"
LOCK = threading.Lock()
SCORES = []  # list of {"name": str, "score": int}


def log(msg):
    print(msg, flush=True)


def load_scores():
    try:
        with open(SCORES_FILE) as f:
            SCORES.extend(json.load(f))
        log("📂 loaded %d scores from %s" % (len(SCORES), SCORES_FILE))
    except (OSError, ValueError):
        log("📂 no saved scores yet, starting with an empty board")


def save_and_exit(signum, frame):
    with LOCK:
        os.makedirs(os.path.dirname(SCORES_FILE), exist_ok=True)
        with open(SCORES_FILE, "w") as f:
            json.dump(SCORES, f)
        log("💾 saved %d scores to %s" % (len(SCORES), SCORES_FILE))
    sys.exit(0)


def top5():
    return sorted(SCORES, key=lambda s: -s["score"])[:5]


class Handler(BaseHTTPRequestHandler):
    def send_body(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/api/scores":
            with LOCK:
                body = json.dumps(top5()).encode()
            self.send_body(200, body, "application/json")
        elif self.path in ("/", "/index.html"):
            with open(os.path.join(HERE, "index.html"), "rb") as f:
                self.send_body(200, f.read(), "text/html; charset=utf-8")
        else:
            self.send_body(404, b"not found", "text/plain")

    def do_POST(self):
        if self.path != "/api/scores":
            return self.send_body(404, b"not found", "text/plain")
        try:
            size = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(size))
            name = str(data["name"]).strip()[:12] or "Anonymous"
            score = max(0, min(int(data["score"]), 100000))
        except (KeyError, TypeError, ValueError):
            return self.send_body(400, b"bad score", "text/plain")
        with LOCK:
            SCORES.append({"name": name, "score": score})
        log("🏆 new score: %s scored %d" % (name, score))
        self.send_body(201, b"{}", "application/json")

    def log_message(self, *args):
        pass  # keep the logs short: we log scores ourselves


if __name__ == "__main__":
    load_scores()
    signal.signal(signal.SIGTERM, save_and_exit)
    log("🥞 Dosa Dash is serving on port 8000")
    ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
