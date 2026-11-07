# Campus status board: checks two apps by NAME every 3 seconds and shows the result.
import threading, time, urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

APPS = ["d09-draw", "d09-tools"]
status = {name: "starting…" for name in APPS}

def check(name):
    try:
        urllib.request.urlopen("http://" + name, timeout=2)
        return True, "up"
    except Exception as e:
        return False, str(getattr(e, "reason", e))

def watch():
    while True:
        for name in APPS:
            up, why = check(name)
            status[name] = "✅" if up else "❌ " + why
            print(("✅ %s up" if up else "❌ %s: %s") % ((name,) if up else (name, why)), flush=True)
        time.sleep(3)

class Page(BaseHTTPRequestHandler):
    def do_GET(self):
        tiles = "".join(
            '<div class="t %s"><b>%s</b><span>%s</span></div>'
            % ("up" if s == "✅" else "down", n, s) for n, s in status.items())
        html = ('<meta charset="utf-8"><meta http-equiv="refresh" content="3"><title>Campus status board</title>'
                '<style>body{font:28px sans-serif;background:#111;color:#eee;text-align:center}'
                '.t{display:inline-block;width:340px;margin:20px;padding:30px;border-radius:20px}'
                '.up{background:#14532d}.down{background:#7f1d1d}b,span{display:block}span{font-size:64px}</style>'
                '<h1>Campus status board</h1>' + tiles)
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode())
    def log_message(self, *args):
        pass

threading.Thread(target=watch, daemon=True).start()
HTTPServer(("", 8000), Page).serve_forever()
