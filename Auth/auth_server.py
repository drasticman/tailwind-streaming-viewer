from http.server import BaseHTTPRequestHandler, HTTPServer
from http.cookies import SimpleCookie
from urllib.parse import parse_qs, urlparse, quote, unquote
import urllib.request
import urllib.error
import time
import hmac
import hashlib
import base64
import html
import json
import os

HOST = "127.0.0.1"
PORT = 8081

PASSWORD = os.getenv("STREAM_PASSWORD")
SECRET = os.getenv("STREAM_SECRET")

print("STREAM_PASSWORD =", PASSWORD)
print("STREAM_SECRET =", SECRET)

if not PASSWORD:
    raise RuntimeError("STREAM_PASSWORD is not set")

if not SECRET:
    raise RuntimeError("STREAM_SECRET is not set")

COOKIE_NAME = "auth"
MAX_AGE = 7 * 24 * 60 * 60  # 7 days

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOGO_PATH = os.path.join(BASE_DIR, "fulllogo.png")
LOGO_URL = f"/{os.path.basename(LOGO_PATH)}"

MEDIAMTX_PATHS_URL = "http://127.0.0.1:9997/v3/paths/list"


def sign(value: str) -> str:
    sig = hmac.new(
        SECRET.encode("utf-8"),
        value.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()
    return f"{value}.{sig}"


def make_cookie() -> str:
    expiry = str(int(time.time()) + MAX_AGE)
    signed = sign(expiry)
    return base64.urlsafe_b64encode(signed.encode("utf-8")).decode("utf-8")


def check_cookie(val: str) -> bool:
    try:
        raw = base64.urlsafe_b64decode(val.encode("utf-8")).decode("utf-8")
        payload, sig = raw.rsplit(".", 1)

        expected = hmac.new(
            SECRET.encode("utf-8"),
            payload.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(sig, expected):
            return False

        return int(payload) > time.time()
    except Exception:
        return False


def sanitize_next(path: str) -> str:
    """
    Only allow internal paths like /A_Cam/
    Prevent open redirects.
    """
    if not path:
        return "/"

    if not path.startswith("/"):
        return "/"

    # prevent protocol injection like //evil.com
    if path.startswith("//"):
        return "/"

    return path


def get_stream_status() -> dict:
    """
    Query local MediaMTX and return a simple truth map, e.g.:
    {
        "A_Cam": true,
        "B_Cam": false
    }

    Any stream not present in the MediaMTX paths list will simply be absent.
    """
    try:
        with urllib.request.urlopen(MEDIAMTX_PATHS_URL, timeout=1.5) as response:
            payload = json.loads(response.read().decode("utf-8"))

        status = {}
        for item in payload.get("items", []):
            name = item.get("name")
            if not name:
                continue

            ready = bool(item.get("ready", False))
            available = bool(item.get("available", False))

            status[name] = ready and available

        return status

    except Exception:
        return {}


class Handler(BaseHTTPRequestHandler):
    def cookies(self):
        c = SimpleCookie()
        if "Cookie" in self.headers:
            c.load(self.headers["Cookie"])
        return {k: v.value for k, v in c.items()}

    def is_authed(self):
        cookie_val = self.cookies().get(COOKIE_NAME)
        return bool(cookie_val) and check_cookie(cookie_val)

    def send_html(self, html_text: str, code: int = 200):
        body = html_text.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, obj, code: int = 200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_file(self, path: str, content_type: str):
        try:
            with open(path, "rb") as f:
                body = f.read()
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except FileNotFoundError:
            self.send_html("Not found", 404)

    def redirect(self, where: str):
        self.send_response(302)
        self.send_header("Location", where)
        self.end_headers()

    def set_cookie_and_redirect(self, where: str):
        val = make_cookie()
        self.send_response(302)
        self.send_header("Location", where)
        self.send_header(
            "Set-Cookie",
            f"{COOKIE_NAME}={val}; Max-Age={MAX_AGE}; Path=/; HttpOnly; Secure; SameSite=Lax"
        )
        self.end_headers()

    def render_login_page(self, error_message: str = "", next_path: str = "/") -> str:
        error_html = ""
        if error_message:
            error_html = f'<div class="error">{html.escape(error_message)}</div>'

        logo_html = ""
        if os.path.exists(LOGO_PATH):
            logo_html = f'<img src="{LOGO_URL}" alt="Tailwind Tech logo" class="logo">'

        next_escaped = html.escape(next_path)

        return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Tailwind Tech Streaming</title>
  <meta property="og:title" content="Tailwind Tech Streaming" />
<meta property="og:description" content="Secure streaming viewer." />
<meta property="og:type" content="website" />
<meta property="og:url" content="https://stream.andybader.com/" />
<meta property="og:image" content="https://stream.andybader.com/share-preview.png" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />

<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="Tailwind Tech Streaming" />
<meta name="twitter:description" content="Secure streaming viewer." />
<meta name="twitter:image" content="https://stream.andybader.com/share-preview.png" />
  <style>
    :root {{
      --graphite: #343638;
      --deep-space: #0b0b0b;
      --misty: #849fb6;
      --cloudless: #c2d7ef;
      --storm-watch: #b9bcc1;
      --danger-bg: rgba(180, 60, 60, 0.18);
      --danger-border: rgba(255, 140, 140, 0.32);
      --danger-text: #ffd1d1;
    }}

    * {{ box-sizing: border-box; }}

    body {{
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      background: var(--graphite);
      color: white;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      padding: 20px;
    }}

    .card {{
      width: min(92vw, 430px);
      background: var(--deep-space);
      border: 1px solid rgba(255,255,255,0.10);
      border-radius: 18px;
      padding: 30px 26px 24px;
      box-shadow: 0 18px 50px rgba(0,0,0,0.35);
      text-align: center;
    }}

    .logo {{
      max-width: 320px;
      max-height: 140px;
      width: 100%;
      height: auto;
      margin: 0 auto 20px;
      display: block;
      object-fit: contain;
    }}

    h1 {{
      margin: 0 0 8px;
      font-size: 24px;
      font-weight: 700;
      color: var(--misty);
    }}

    p {{
      margin: 0 0 18px;
      color: var(--storm-watch);
      font-size: 14px;
    }}

    .error {{
      margin: 0 0 14px;
      padding: 11px 12px;
      border-radius: 12px;
      background: var(--danger-bg);
      border: 1px solid var(--danger-border);
      color: var(--danger-text);
      font-size: 14px;
      text-align: left;
    }}

    input {{
      width: 100%;
      padding: 13px 14px;
      border-radius: 12px;
      border: 1px solid rgba(255,255,255,0.14);
      background: #111;
      color: white;
      margin-bottom: 12px;
      font-size: 16px;
    }}

    button {{
      width: 100%;
      padding: 13px 14px;
      border-radius: 12px;
      border: none;
      background: var(--misty);
      color: var(--deep-space);
      font-size: 16px;
      font-weight: 700;
      cursor: pointer;
    }}
  </style>
</head>
<body>
  <div class="card">
    {logo_html}
    <h1>Tailwind Tech Streaming</h1>
    <p>Please enter the password to continue.</p>
    {error_html}
    <form method="post" action="/login">
      <input type="hidden" name="next" value="{next_escaped}" />
      <input type="password" name="password" placeholder="Password" autofocus />
      <button type="submit">Enter</button>
    </form>
  </div>
</body>
</html>"""

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == LOGO_URL:
            self.send_file(LOGO_PATH, "image/png")
            return

        if parsed.path == "/stream-status":
            if not self.is_authed():
                next_path = self.headers.get("X-Forwarded-Uri", "/")
                next_path = sanitize_next(next_path)
                self.redirect(f"/login?next={quote(next_path)}")
                return

            self.send_json(get_stream_status())
            return

        if parsed.path == "/auth/check":
            if self.is_authed():
                self.send_response(204)
                self.end_headers()
            else:
                next_path = self.headers.get("X-Forwarded-Uri", "/")
                next_path = sanitize_next(next_path)
                self.redirect(f"/login?next={quote(next_path)}")
            return

        if parsed.path == "/login":
            query = parse_qs(parsed.query)
            next_path = sanitize_next(query.get("next", ["/"])[0])
            self.send_html(self.render_login_page(next_path=next_path))
            return

        self.send_html("Not found", 404)

    def do_POST(self):
        if self.path != "/login":
            self.send_html("Not found", 404)
            return

        length = int(self.headers.get("Content-Length", 0))
        data = self.rfile.read(length).decode("utf-8")
        form = parse_qs(data)

        submitted_password = form.get("password", [""])[0]
        next_path = sanitize_next(unquote(form.get("next", ["/"])[0]))

        if submitted_password == PASSWORD:
            self.set_cookie_and_redirect(next_path)
        else:
            self.send_html(
                self.render_login_page(
                    error_message="Incorrect password. Please try again.",
                    next_path=next_path
                ),
                401
            )


if __name__ == "__main__":
    print("Auth server running on 127.0.0.1:8081")
    HTTPServer((HOST, PORT), Handler).serve_forever()