import http.server
import socketserver
import webbrowser
import os
import sys
import threading
import time

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

PORT = 5000
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

possible_paths = [
    os.path.join(BASE_DIR, "namba_admin", "build", "web"),
    os.path.join(BASE_DIR, "build", "web"),
]

DIRECTORY = None
for p in possible_paths:
    if os.path.exists(p) and os.path.exists(os.path.join(p, "index.html")):
        DIRECTORY = p
        break

if not DIRECTORY:
    print("Error: build/web not found.")
    sys.exit(1)

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def log_message(self, format, *args):
        pass

def open_browser():
    time.sleep(1)
    url = f"http://localhost:{PORT}"
    print(f"Opening {url} in your browser...")
    webbrowser.open(url)

if __name__ == "__main__":
    print("=" * 60)
    print("NAMBA ADMIN SERVER (Zero-CPU Lightweight Runner)")
    print(f"Serving: {DIRECTORY}")
    print(f"URL: http://localhost:{PORT}")
    print("=" * 60)

    threading.Thread(target=open_browser, daemon=True).start()

    socketserver.TCPServer.allow_reuse_address = True
    try:
        with socketserver.TCPServer(("", PORT), Handler) as httpd:
            print(f"Server is LIVE on http://localhost:{PORT}")
            print("Press Ctrl+C to stop.")
            httpd.serve_forever()
    except OSError as e:
        print(f"Port in use, opening http://localhost:{PORT}")
        webbrowser.open(f"http://localhost:{PORT}")
