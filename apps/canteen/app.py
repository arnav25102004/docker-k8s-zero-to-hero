"""
🍵 Canteen Rush: the ordering app behind the two course projects (Kubernetes labs 5 and 6).

Standard library only (no pip install), so it builds in seconds and runs anywhere.
It is deliberately small: the point is the platform around it, not the code.

What makes it a good project app
  * Every answer says WHICH container served it  -> load balancing and scaling, visible
  * Orders live in memory (per container!) or Redis -> why state belongs outside containers
  * A crash button and a CPU burner                 -> self-healing and autoscaling, on demand
  * The menu comes from a file or env var           -> ConfigMaps (the page updates live)
  * A protected "close the day" endpoint            -> Secrets, Jobs and CronJobs
  * A version banner (APP_VERSION)                  -> rolling updates and rollbacks

Endpoints
  GET  /                      the web page
  GET  /api/info              title, version, hostname, menu, storage
  GET|POST /api/order?item=chai   order one item (GET makes curl demos easy)
  GET  /api/stats             orders so far today
  GET  /api/report            today's numbers as a small report (what the nightly Job prints)
  POST /api/admin/close-day   save today's report and start a fresh day (needs X-Admin-Token)
  GET  /api/admin/history     the saved daily reports (needs X-Admin-Token)
  GET|POST /api/crash         exit the process with code 1 (chaos engineering!)
  GET  /api/burn?seconds=N    burn CPU for N seconds (to trigger autoscaling)
  GET  /healthz               liveness: the process is alive
  GET  /readyz                readiness: ready for traffic (checks Redis if configured)

Configuration (environment variables)
  PORT           default 8080
  APP_VERSION    default 1.0.0
  TITLE          default "Canteen Rush"
  THEME_COLOR    default "#e85d04"
  MENU           default "chai|🍵|Chai|10,samosa|🥟|Samosa|15,dosa|🥞|Dosa|40" (id|emoji|name|price)
  MENU_FILE      default /etc/canteen/menu.txt: one "id|emoji|name|price" per line. If the file
                 exists it wins over MENU, and it is re-read on every request (so a ConfigMap
                 mounted there changes the live menu without a restart).
  ADMIN_TOKEN    secret for /api/admin/*. Empty = the admin endpoints are switched off.
  REDIS_HOST     Redis hostname. Empty = keep orders in this container's memory
  REDIS_PORT     default 6379
  STARTUP_DELAY  seconds to sleep before listening (simulates a slow boot), default 0
"""

import hmac
import json
import os
import signal
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get("PORT", "8080"))
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
TITLE = os.environ.get("TITLE", "Canteen Rush")
THEME_COLOR = os.environ.get("THEME_COLOR", "#e85d04")
DEFAULT_MENU = "chai|🍵|Chai|10,samosa|🥟|Samosa|15,dosa|🥞|Dosa|40"
MENU_ENV = os.environ.get("MENU", DEFAULT_MENU)
MENU_FILE = Path(os.environ.get("MENU_FILE", "/etc/canteen/menu.txt"))
ADMIN_TOKEN = os.environ.get("ADMIN_TOKEN", "")
REDIS_HOST = os.environ.get("REDIS_HOST", "")
# Kubernetes injects REDIS_PORT=tcp://10.96.x.x:6379 when a Service named "redis" exists.
# Accept both "6379" and that URL form.
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379").rsplit(":", 1)[-1])
STARTUP_DELAY = float(os.environ.get("STARTUP_DELAY", "0"))
HOSTNAME = socket.gethostname()
STARTED_AT = time.time()
INDEX_HTML = (Path(__file__).parent / "static" / "index.html").read_bytes()


def parse_menu(lines):
    menu = []
    for raw in lines:
        parts = [p.strip() for p in raw.split("|")]
        if len(parts) == 4 and parts[0] and parts[3].isdigit():
            menu.append({"id": parts[0], "emoji": parts[1], "name": parts[2], "price": int(parts[3])})
    return menu


def current_menu():
    """The menu file wins when it exists; it is read every time, so edits show up live."""
    try:
        menu = parse_menu(MENU_FILE.read_text(encoding="utf-8").splitlines())
        if menu:
            return menu
    except OSError:
        pass
    return parse_menu(MENU_ENV.split(","))


def log(msg):
    # Containers log to stdout/stderr, never to files inside the container.
    print(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} [{HOSTNAME}] {msg}", flush=True)


# ---------------------------------------------------------------- storage --
class MemoryStore:
    """Orders in THIS container's RAM: lost on restart, different in every replica."""
    kind = "memory"

    def __init__(self):
        self.orders, self.days, self.lock = {}, [], threading.Lock()

    def incr(self, item):
        with self.lock:
            self.orders[item] = self.orders.get(item, 0) + 1

    def counts(self):
        with self.lock:
            return dict(self.orders)

    def close_day(self, report):
        with self.lock:
            self.days.append(json.dumps(report, ensure_ascii=False))
            self.orders.clear()

    def history(self):
        with self.lock:
            return [json.loads(d) for d in self.days]

    def ping(self):
        return True


class RedisStore:
    """Orders in Redis: shared by every replica, survives restarts. Speaks raw RESP."""
    kind = "redis"

    def _call(self, *parts):
        payload = f"*{len(parts)}\r\n" + "".join(f"${len(p.encode())}\r\n{p}\r\n" for p in parts)
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

    def incr(self, item):
        self._call("HINCRBY", "orders", item, "1")

    def counts(self):
        flat = self._call("HGETALL", "orders") or []
        return {flat[i]: int(flat[i + 1]) for i in range(0, len(flat), 2)}

    def close_day(self, report):
        self._call("RPUSH", "days", json.dumps(report, ensure_ascii=False))
        self._call("DEL", "orders")

    def history(self):
        return [json.loads(d) for d in (self._call("LRANGE", "days", "0", "-1") or [])]

    def ping(self):
        return self._call("PING") == "PONG"


STORE = RedisStore() if REDIS_HOST else MemoryStore()


def stats():
    menu, counts = current_menu(), STORE.counts()
    by_item = [{"id": m["id"], "emoji": m["emoji"], "name": m["name"], "price": m["price"],
                "orders": counts.get(m["id"], 0)} for m in menu]
    return {"by_item": by_item,
            "total_orders": sum(i["orders"] for i in by_item),
            "revenue": sum(i["orders"] * i["price"] for i in by_item),
            "storage": STORE.kind, "served_by": HOSTNAME, "version": APP_VERSION}


def report():
    s = stats()
    best = max(s["by_item"], key=lambda i: i["orders"]) if s["by_item"] else None
    return {"date": time.strftime("%Y-%m-%d %H:%M:%S"),
            "total_orders": s["total_orders"], "revenue": s["revenue"],
            "best_seller": best["name"] if best and best["orders"] else None,
            "by_item": {i["name"]: i["orders"] for i in s["by_item"]}}


# ------------------------------------------------------------------- http --
class Handler(BaseHTTPRequestHandler):
    server_version = "canteen-rush"

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
        if any(p in self.path for p in ("/healthz", "/readyz", "/api/info", "/api/stats")):
            return  # keep logs readable: skip the page's polling and the probes
        log(f"{self.client_address[0]} {fmt % args}")

    def do_POST(self):
        self.handle_request()

    def do_GET(self):
        self.handle_request()

    def handle_request(self):
        url = urlparse(self.path)
        path, query = url.path.rstrip("/") or "/", parse_qs(url.query)
        try:
            self.route(path, query)
        except Exception as e:  # dependency failures become clean 503s, not stack traces
            log(f"ERROR {path}: {e} (storage={STORE.kind} {REDIS_HOST}:{REDIS_PORT})")
            self._send(503, {"error": str(e), "storage": STORE.kind, "served_by": HOSTNAME})

    def admin_ok(self):
        if not ADMIN_TOKEN:
            self._send(503, {"error": "admin endpoints are switched off (ADMIN_TOKEN is not set)"})
            return False
        given = self.headers.get("X-Admin-Token", "")
        if not hmac.compare_digest(given.encode(), ADMIN_TOKEN.encode()):
            log("admin request with a wrong token")
            self._send(401, {"error": "wrong or missing X-Admin-Token"})
            return False
        return True

    def route(self, path, query):
        if path in ("/", "/index.html"):
            self._send(200, INDEX_HTML, "text/html; charset=utf-8")
        elif path == "/api/info":
            self._send(200, {"app": "canteen-rush", "title": TITLE, "version": APP_VERSION,
                             "hostname": HOSTNAME, "menu": current_menu(), "storage": STORE.kind,
                             "theme": THEME_COLOR, "uptime_seconds": int(time.time() - STARTED_AT)})
        elif path == "/api/stats":
            self._send(200, stats())
        elif path == "/api/order":
            item = (query.get("item") or [""])[0]
            valid = {m["id"] for m in current_menu()}
            if item not in valid:
                self._send(400, {"error": f"'{item}' is not on the menu", "menu": sorted(valid)})
                return
            STORE.incr(item)
            log(f"order: {item}")
            self._send(200, {"ordered": item, **stats()})
        elif path == "/api/report":
            self._send(200, report())
        elif path == "/api/admin/close-day":
            if self.command != "POST":
                self._send(405, {"error": "use POST"})
            elif self.admin_ok():
                r = report()
                STORE.close_day(r)
                log(f"day closed: {r['total_orders']} orders, revenue {r['revenue']}")
                self._send(200, {"closed": True, "report": r})
        elif path == "/api/admin/history":
            if self.admin_ok():
                self._send(200, {"days": STORE.history()})
        elif path == "/api/crash":
            log("💥 crash requested: exiting with code 1")
            self._send(200, {"crashing": True, "served_by": HOSTNAME})
            threading.Timer(0.2, lambda: os._exit(1)).start()
        elif path == "/api/burn":
            seconds = min(float((query.get("seconds") or ["1"])[0]), 30)
            end = time.time() + seconds
            while time.time() < end:
                sum(i * i for i in range(10000))
            self._send(200, {"burned_seconds": seconds, "served_by": HOSTNAME})
        elif path == "/healthz":
            self._send(200, {"status": "ok"})
        elif path == "/readyz":
            ready = STORE.ping()
            self._send(200 if ready else 503, {"ready": ready, "storage": STORE.kind})
        else:
            self._send(404, {"error": "not found", "path": path})


def main():
    if STARTUP_DELAY:
        log(f"warming up for {STARTUP_DELAY}s before listening…")
        time.sleep(STARTUP_DELAY)
    server = ThreadingHTTPServer(("", PORT), Handler)
    log(f"🍵 {TITLE} v{APP_VERSION} listening on :{PORT}, orders stored in {STORE.kind}"
        f"{' (' + REDIS_HOST + ')' if REDIS_HOST else ''}")
    # As PID 1 in a container, Python ignores SIGTERM unless a handler exists. Without this,
    # `kubectl delete pod` would wait the whole grace period (30 s) before killing us.
    signal.signal(signal.SIGTERM, lambda *_: threading.Thread(target=server.shutdown).start())
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    log("shutting down")


if __name__ == "__main__":
    main()
