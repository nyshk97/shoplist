# 通信の遅延を再現する中継（8788 → 8787、各リクエストに 0.8 秒の遅延）
import http.server, urllib.request, time
class H(http.server.BaseHTTPRequestHandler):
    def _go(self):
        time.sleep(0.8)
        n = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(n) if n else None
        req = urllib.request.Request('http://localhost:8787' + self.path, data=body, method=self.command,
                                     headers={k: v for k, v in self.headers.items() if k.lower() in ('authorization', 'content-type')})
        try:
            r = urllib.request.urlopen(req); code, data = r.status, r.read()
        except urllib.error.HTTPError as e:
            code, data = e.code, e.read()
        self.send_response(code); self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data))); self.end_headers(); self.wfile.write(data)
    do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = _go
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(('127.0.0.1', 8788), H).serve_forever()
