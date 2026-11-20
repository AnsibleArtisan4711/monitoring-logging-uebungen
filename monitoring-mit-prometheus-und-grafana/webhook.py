#!/usr/bin/env python3
"""Kleiner Webhook-Empfänger für den Alertmanager (nur Loopback). Schreibt je Benachrichtigung eine Zeile in die Datei aus Argument 2."""
import sys, json
from http.server import BaseHTTPRequestHandler, HTTPServer
LOG = sys.argv[2]
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        d = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        names = sorted(a['labels'].get('alertname', '?') + '@' + a['labels'].get('instance', '-') for a in d['alerts'])
        with open(LOG, 'a') as f:
            f.write('status=%s receiver=%s group=%s alerts=%s\n' % (d['status'], d['receiver'], json.dumps(d['groupLabels'], sort_keys=True), ','.join(names)))
        self.send_response(200); self.end_headers()
    def log_message(self, *a): pass
HTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
