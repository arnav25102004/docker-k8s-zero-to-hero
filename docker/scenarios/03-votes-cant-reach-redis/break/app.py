"""
🐱 vs 🐶  "The Showdown": the live voting app used in every lab of this course.

Standard library only (no pip install), so it builds in seconds and runs anywhere.

What makes it a great teaching app
  * Every response says WHICH container/pod served it  -> see load balancing & scaling live
  * Votes live in memory (per container!) or in Redis   -> see why state belongs outside containers
  * A chaos button kills the server on purpose          -> see self-healing live
  * Options/version/title come from env vars             -> see config + rolling updates live

Endpoints
  GET  /                    the web UI (static/index.html)
  GET  /api/info            version, title, hostname, options, storage
  GET  /api/results         current vote counts
  GET|POST /api/vote?option=cats   cast a vote (GET makes curl demos easy)
  POST /api/reset           reset all votes
  GET|POST /api/crash       💥 exit the process with code 1 (chaos engineering!)
  GET  /api/burn?seconds=N  burn CPU for N seconds (to trigger autoscaling)
  GET  /healthz             liveness: the process is alive
  GET  /readyz              readiness: ready for traffic (checks Redis if configured)

Configuration (environment variables)
  PORT           default 8080
  APP_VERSION    default 1.0.0
  TITLE          default "Cats vs Dogs"
  VOTE_OPTIONS   default "cats:🐱:Cats,dogs:🐶:Dogs"   (id:emoji:label, comma separated)
  THEME_COLOR    default "#ff5a5f"
  REDIS_HOST     Redis hostname. Empty = store votes in this container's memory
  REDIS_PORT     default 6379
  STARTUP_DELAY  seconds to sleep before listening (simulates a slow boot), default 0
"""

import json
import os
import signal
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get("PORT", "8080"))
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
TITLE = os.environ.get("TITLE", "Cats vs Dogs")
THEME_COLOR = os.environ.get("THEME_COLOR", "#ff5a5f")
REDIS_HOST = os.environ.get("REDIS_HOST", "")
# Careful: Kubernetes injects REDIS_PORT=tcp://10.96.x.x:6379 into every Pod when a Service
# named "redis" exists (legacy "service links"). Accept both "6379" and that URL form.
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379").rsplit(":", 1)[-1])
STARTUP_DELAY = float(os.environ.get("STARTUP_DELAY", "0"))
HOSTNAME = socket.gethostname()
STARTED_AT = time.time()
INDEX_HTML = (Path(__file__).parent / "static" / "index.html").read_bytes()


def parse_options(raw):
    options = []
    for item in raw.split(","):
        parts = [p.strip() for p in item.split(":")]
        if len(parts) == 3 and parts[0]:
            options.append({"id": parts[0], "emoji": parts[1], "label": parts[2]})
    return options


OPTIONS = parse_options(os.environ.get("VOTE_OPTIONS", "cats:🐱:Cats,dogs:🐶:Dogs"))
OPTION_IDS = {o["id"] for o in OPTIONS}


def log(msg):
    # Containers log to stdout/stderr, never to files inside the container.
    print(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} [{HOSTNAME}] {msg}", flush=True)


# ---------------------------------------------------------------- storage --
class MemoryStore:
    """Votes in THIS container's RAM: lost on restart, different in every replica."""
    kind = "memory"

    def __init__(self):
        self.votes = {}
        self.lock = threading.Lock()

    def incr(self, option):
        with self.lock:
            self.votes[option] = self.votes.get(option, 0) + 1

    def all(self):
        with self.lock:
            return dict(self.votes)

    def reset(self):
        with self.lock:
            self.votes.clear()

    def ping(self):
        return True


class RedisStore:
    """Votes in Redis, shared by every replica, survives restarts. Speaks raw RESP."""
    kind = "redis"

    def _call(self, *parts):
        payload = f"*{len(parts)}\r\n" + "".join(
            f"${len(p.encode())}\r\n{p}\r\n" for p in parts)
        with socket.create_connection((REDIS_HOST, REDIS_PORT), timeout=2) as s:
            s.sendall(payload.encode())
            return self._read(s.makefile("rb"))

    def _read(self, f):
        line = f.readline().decode().rstrip("\r\n")
        kind, rest = line[:1], line[1:]
        if kind == "+":
            return rest
        if kind == "-":
            raise RuntimeError(rest)
        if kind == ":":
            return int(rest)
        if kind == "$":
            if rest == "-1":
                return None
            data = f.read(int(rest) + 2)
            return data[:-2].decode()
        if kind == "*":
            return [self._read(f) for _ in range(int(rest))]
        raise RuntimeError(f"unexpected redis reply: {line!r}")

    def incr(self, option):
        self._call("HINCRBY", "votes", option, "1")

    def all(self):
        flat = self._call("HGETALL", "votes") or []
        return {flat[i]: int(flat[i + 1]) for i in range(0, len(flat), 2)}

    def reset(self):
        self._call("DEL", "votes")

    def ping(self):
        return self._call("PING") == "PONG"


STORE = RedisStore() if REDIS_HOST else MemoryStore()


def results():
    votes = STORE.all()
    counts = {o["id"]: votes.get(o["id"], 0) for o in OPTIONS}
    return {"results": counts, "total": sum(counts.values()),
            "storage": STORE.kind, "served_by": HOSTNAME, "version": APP_VERSION}


# ------------------------------------------------------------------- http --
class Handler(BaseHTTPRequestHandler):
    server_version = "z2h-showdown"

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Served-By", HOSTNAME)
        self.send_header("X-App-Version", APP_VERSION)
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        if "/healthz" in self.path or "/readyz" in self.path or "/api/info" in self.path \
                or "/api/results" in self.path:
            return  # keep logs readable: skip the UI's polling and probe noise
        log(f"{self.client_address[0]} {fmt % args}")

    def do_POST(self):
        self.do_GET()

    def do_GET(self):
        url = urlparse(self.path)
        path, query = url.path.rstrip("/") or "/", parse_qs(url.query)
        try:
            self.route(path, query)
        except Exception as e:  # dependency failures become clean 503s, not stack traces
            log(f"ERROR {path}: {e} (storage={STORE.kind} {REDIS_HOST}:{REDIS_PORT})")
            self._send(503, {"error": str(e), "storage": STORE.kind,
                             "redis": f"{REDIS_HOST}:{REDIS_PORT}" if REDIS_HOST else None,
                             "served_by": HOSTNAME})

    def route(self, path, query):
        if path in ("/", "/index.html"):
            self._send(200, INDEX_HTML, "text/html; charset=utf-8")
        elif path == "/api/info":
            self._send(200, {"app": "z2h-showdown", "title": TITLE, "version": APP_VERSION,
                             "hostname": HOSTNAME, "options": OPTIONS, "storage": STORE.kind,
                             "theme": THEME_COLOR, "uptime_seconds": int(time.time() - STARTED_AT)})
        elif path == "/api/results":
            self._send(200, results())
        elif path == "/api/vote":
            option = (query.get("option") or [""])[0]
            if self.command == "POST" and not option:
                length = int(self.headers.get("Content-Length") or 0)
                option = json.loads(self.rfile.read(length) or b"{}").get("option", "")
            if option not in OPTION_IDS:
                self._send(400, {"error": f"unknown option '{option}'",
                                 "valid": sorted(OPTION_IDS)})
                return
            STORE.incr(option)
            log(f"vote for {option}")
            self._send(200, {"voted": option, **results()})
        elif path == "/api/reset":
            STORE.reset()
            log("votes reset")
            self._send(200, results())
        elif path == "/api/crash":
            log("💥 CRASH requested via /api/crash, exiting with code 1")
            self._send(200, {"status": "crashing", "served_by": HOSTNAME})
            self.wfile.flush()
            os._exit(1)
        elif path == "/api/burn":
            seconds = min(float((query.get("seconds") or ["5"])[0]), 60)
            end, n = time.time() + seconds, 0
            while time.time() < end:
                n += 1
            self._send(200, {"burned_seconds": seconds, "iterations": n, "served_by": HOSTNAME})
        elif path == "/healthz":
            self._send(200, {"status": "alive", "served_by": HOSTNAME})
        elif path == "/readyz":
            try:
                STORE.ping()
                self._send(200, {"status": "ready", "storage": STORE.kind})
            except Exception as e:
                log(f"readiness failed: cannot reach redis at {REDIS_HOST}:{REDIS_PORT}: {e}")
                self._send(503, {"status": "not ready",
                                 "error": f"redis {REDIS_HOST}:{REDIS_PORT}: {e}"})
        else:
            self._send(404, {"error": "not found", "path": path})


class DualStackServer(ThreadingHTTPServer):
    """Listen on IPv6 and IPv4 at once. In Kubernetes Pods "localhost" resolves to ::1 first."""
    address_family = socket.AF_INET6

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


def make_server():
    try:
        return DualStackServer(("::", PORT), Handler)
    except OSError:  # kernel without IPv6
        return ThreadingHTTPServer(("0.0.0.0", PORT), Handler)


def shutdown(signum, frame):
    # Docker and Kubernetes send SIGTERM before SIGKILL. Exit cleanly and quickly.
    log(f"received signal {signum}, shutting down gracefully 👋")
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, shutdown)
    if STARTUP_DELAY > 0:
        log(f"simulating slow startup: sleeping {STARTUP_DELAY}s")
        time.sleep(STARTUP_DELAY)
    names = " vs ".join(o["label"] for o in OPTIONS)
    log(f"🚀 {TITLE} v{APP_VERSION} ({names}) listening on :{PORT}, "
        f"votes stored in {'redis ' + REDIS_HOST if REDIS_HOST else 'MEMORY (this container only)'}")
    make_server().serve_forever()
