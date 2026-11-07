# Campus status board: checks two apps by NAME every 3 seconds and shows the result.
import threading, time, urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

APPS = ["d09-draw", "d09-tools"]
status = {name: (None, "starting…") for name in APPS}

def check(name):
    try:
        urllib.request.urlopen("http://" + name, timeout=2)
        return True, "up"
    except Exception as e:
        return False, str(getattr(e, "reason", e))

def short(why):
    low = why.lower()
    if "name" in low or "resolution" in low:
        return "can't find this name"
    return "timeout" if "time" in low else "error"

def watch():
    while True:
        for name in APPS:
            up, why = check(name)
            status[name] = (up, why)
            print(("✅ %s up" if up else "❌ %s: %s") % ((name,) if up else (name, why)), flush=True)
        time.sleep(3)

class Page(BaseHTTPRequestHandler):
    def do_GET(self):
        tiles = "".join(
            '<div class="t %s"><b>%s</b><i>%s</i><small>%s</small></div>'
            % ("up" if up else "down", n, "✅" if up else "❌", "up" if up else short(why))
            for n, (up, why) in status.items())
        html = ('<meta charset="utf-8"><meta http-equiv="refresh" content="3"><title>Campus status board</title>'
                '<style>body{font-family:sans-serif;background:#111;color:#fff;text-align:center}'
                '.t{display:inline-block;width:400px;margin:20px;padding:30px;border-radius:20px;color:#fff}'
                '.up{background:#15803d}.down{background:#dc2626}'
                'b{display:block;font-size:40px}i{display:block;font-size:64px;font-style:normal}'
                'small{display:block;font-size:22px}</style>'
                '<h1>Campus status board</h1>' + tiles)
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode())
    def log_message(self, *args):
        pass

threading.Thread(target=watch, daemon=True).start()
HTTPServer(("", 8000), Page).serve_forever()
