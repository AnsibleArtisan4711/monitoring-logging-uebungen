#!/usr/bin/env python3
"""Eigener Mini-Exporter im Prometheus-Textformat (nur Loopback). Zähler steigt bei jedem Abruf, die Warteschlange ist ein fester Messwert."""
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
n = 0
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        global n
        if self.path != '/metrics':
            self.send_response(404); self.end_headers(); return
        n += 1
        body = ('# HELP uebung_abrufe_total Anzahl der Abrufe dieses Exporters.\n# TYPE uebung_abrufe_total counter\nuebung_abrufe_total %d\n'
                '# HELP uebung_warteschlange_laenge Elemente in der Warteschlange (fester Beispielwert).\n# TYPE uebung_warteschlange_laenge gauge\nuebung_warteschlange_laenge{queue="mail"} 7\nuebung_warteschlange_laenge{queue="druck"} 0\n' % n).encode()
        self.send_response(200); self.send_header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8'); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
HTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
