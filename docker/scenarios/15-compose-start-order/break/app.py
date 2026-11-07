"""Dosa ratings board, Bengaluru edition. Standard library only.

At start it makes ONE attempt to reach the database at db:5432. No retries.
If the database isn't accepting connections yet, it says so and exits with code 1.
The page only proves that the connection worked; the ratings themselves are
made-up demo data, not read from the database.
"""
import socket
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

DB_HOST, DB_PORT = "db", 5432

RATINGS = [
    ("Benne masala dosa", "a famous old Basavanagudi restaurant", "9.5"),
    ("Set dosa with sagu", "a Malleshwaram tiffin room", "9.0"),
    ("Mysore masala dosa", "the canteen near the library", "8.5"),
    ("Plain paper dosa", "the hostel mess, Sunday special", "7.0"),
]

try:
    socket.create_connection((DB_HOST, DB_PORT), timeout=3).close()
except OSError as err:
    print(f"❌ database not reachable ({DB_HOST}:{DB_PORT}): {err}", flush=True)
    sys.exit(1)

print("✅ connected to the database", flush=True)


def page():
    rows = "".join(
        f"<tr><td>{dish}</td><td>{where}</td><td>{score} / 10</td></tr>"
        for dish, where, score in RATINGS
    )
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Dosa ratings board</title>
<style>
body{{font-family:system-ui,sans-serif;max-width:640px;margin:40px auto;padding:0 16px}}
.ok{{color:#0a7d33;font-weight:700;font-size:1.2em}}
table{{border-collapse:collapse;width:100%;margin-top:16px}}
td,th{{border-bottom:1px solid #ddd;padding:8px;text-align:left}}
</style></head><body>
<h1>🥞 Dosa ratings board</h1>
<p class="ok">✅ connected to the database</p>
<table><tr><th>Dosa</th><th>Where</th><th>Rating</th></tr>{rows}</table>
</body></html>""".encode()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = page()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("🌐 " + fmt % args, flush=True)


print("🥞 Dosa ratings board is serving on port 8000", flush=True)
HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
