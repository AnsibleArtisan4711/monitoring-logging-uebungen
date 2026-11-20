#!/usr/bin/env python3
"""Erzeugt erfundene Logdaten (JSON je Zeile) für einen Tag: python3 gen_logs.py AUSGABE.jsonl
Feste Zufallsfolge (seed 42). Rechner: srv01 (Webserver), srv02 (Anmeldungen), fw01 (Firewall). Alle Namen und Adressen sind erfunden.
Eingebaute Vorfälle: 03:10 Portscan von 10.18.0.77 (fw01), 14:02 Passwortraten von 10.18.0.99 gegen srv02, 16:30 Fehlerwelle (HTTP 500) auf srv01."""
import json, random, sys
from datetime import datetime, timedelta, timezone
R = random.Random(42)
T0 = datetime(2026, 10, 26, 0, 0, 0, tzinfo=timezone(timedelta(hours=1)))
ev = []
def add(t, host, prog, level, fac, msg, **f):
    d = {"zeit": t.isoformat(), "host": host, "programm": prog, "level": level, "facility": fac, "nachricht": msg}; d.update(f); ev.append(d)
def tag_zeit():   # Tageszeit mit mehr Verkehr zwischen 8 und 18 Uhr
    while True:
        s = R.randint(0, 86399)
        if R.random() < (0.9 if 8*3600 <= s < 18*3600 else 0.25): return T0 + timedelta(seconds=s)
pfade = ["/", "/index.html", "/login", "/produkte", "/suche", "/api/status", "/kontakt", "/bilder/logo.png"]
clients = ["10.18.0.%d" % i for i in range(31, 41)]
for _ in range(2000):
    t = tag_zeit(); p = R.choice(pfade); st = R.choices([200, 304, 404, 500], [88, 6, 5, 1])[0]; b = R.randint(200, 9000); d = max(5, int(R.gauss(60, 25)))
    ip = R.choice(clients)
    add(t, "srv01", "nginx", 6 if st < 500 else 3, "local7", f"{ip} GET {p} {st} {b} {d}ms", ip=ip, methode="GET", pfad=p, status=st, bytes=b, dauer_ms=d)
for k in range(150):   # Fehlerwelle 16:30 bis 16:40: viele 500er, langsam
    t = T0 + timedelta(hours=16, minutes=30, seconds=R.randint(0, 599)); ip = R.choice(clients); d = R.randint(900, 3000)
    add(t, "srv01", "nginx", 3, "local7", f"{ip} GET /api/status 500 120 {d}ms", ip=ip, methode="GET", pfad="/api/status", status=500, bytes=120, dauer_ms=d)
for _ in range(100):
    t = tag_zeit(); u = R.choice(["anna", "ben", "cara"]); ip = R.choice(clients)
    add(t, "srv02", "sshd", 6, "auth", f"Accepted password for {u} from {ip} port {R.randint(40000, 60000)} ssh2", ereignis="anmeldung_ok", benutzer=u, ip=ip)
for _ in range(30):
    t = tag_zeit(); u = R.choice(["anna", "ben", "cara"]); ip = R.choice(clients)
    add(t, "srv02", "sshd", 6, "auth", f"Failed password for {u} from {ip} port {R.randint(40000, 60000)} ssh2", ereignis="anmeldung_fehler", benutzer=u, ip=ip)
for k in range(40):    # Passwortraten 14:02 bis 14:03
    t = T0 + timedelta(hours=14, minutes=2, seconds=int(k * 1.4)); u = R.choice(["admin", "root", "ben", "test"])
    add(t, "srv02", "sshd", 6, "auth", f"Failed password for {u} from 10.18.0.99 port {R.randint(40000, 60000)} ssh2", ereignis="anmeldung_fehler", benutzer=u, ip="10.18.0.99")
add(T0 + timedelta(hours=14, minutes=3, seconds=5), "srv02", "sshd", 6, "auth", "Accepted password for ben from 10.18.0.99 port 52000 ssh2", ereignis="anmeldung_ok", benutzer="ben", ip="10.18.0.99")
for _ in range(350):
    t = tag_zeit(); q = R.choice(clients); port = R.choice([80, 443, 53, 22])
    add(t, "fw01", "firewall", 6, "local6", f"ALLOW tcp {q} -> 10.18.0.10:{port}", aktion="allow", quelle=q, ziel="10.18.0.10", port=port)
for _ in range(25):
    t = T0 + timedelta(hours=3, minutes=10, seconds=R.randint(0, 119)); port = R.choice(range(20, 1025))
    add(t, "fw01", "firewall", 5, "local6", f"DENY tcp 10.18.0.77 -> 10.18.0.10:{port}", aktion="deny", quelle="10.18.0.77", ziel="10.18.0.10", port=port)
for _ in range(25):
    t = tag_zeit(); q = R.choice(clients); port = R.choice([23, 3389, 445])
    add(t, "fw01", "firewall", 5, "local6", f"DENY tcp {q} -> 10.18.0.10:{port}", aktion="deny", quelle=q, ziel="10.18.0.10", port=port)
ev.sort(key=lambda e: e["zeit"])
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    for e in ev: fh.write(json.dumps(e, ensure_ascii=False) + "\n")
print(len(ev), "Ereignisse")
