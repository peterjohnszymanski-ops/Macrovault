import os, http.server, socketserver, functools
D = '/Users/peterszymanski/Projects/macrovault/web_preview'
try:
    os.chdir(D)
except Exception:
    pass
Handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=D)
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('127.0.0.1', 5500), Handler) as httpd:
    httpd.serve_forever()
