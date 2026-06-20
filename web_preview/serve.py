"""Minimal static server for the MacroVault web preview.

Avoids the sandbox getcwd restriction by chdir-ing to an absolute directory
before anything reads the current working directory, and by passing an explicit
`directory` to the handler so it never calls os.getcwd().
"""
import functools
import http.server
import os
import socketserver
import sys

DIRECTORY = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5173

os.chdir(DIRECTORY)

class _NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def log_message(self, *args):
        pass


Handler = functools.partial(_NoCache, directory=DIRECTORY)


class Server(socketserver.TCPServer):
    allow_reuse_address = True


with Server(("127.0.0.1", PORT), Handler) as httpd:
    print(f"MacroVault preview serving {DIRECTORY} on http://127.0.0.1:{PORT}")
    httpd.serve_forever()
