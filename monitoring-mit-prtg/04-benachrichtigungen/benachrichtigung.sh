#!/usr/bin/env bash
# Modul 4: Benachrichtigungen. MODELL (prtg.py): Auslöser, Verzögerung, Wiederholung, Eskalation. Echt ist ein lokaler Webhook-Empfänger und der Versand an ihn per curl.
. "$(dirname "$0")/../lab.sh"
lab_up
export PYTHONPATH="$HERE"
cat > "$W/hook.py" <<'PY'
import http.server, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(s):
        n = int(s.headers.get("Content-Length", 0)); b = s.rfile.read(n).decode()
        open(sys.argv[1] + "/hook.log", "a").write(b + "\n"); s.send_response(200); s.end_headers(); s.wfile.write(b"ok")
    def log_message(*a): pass
http.server.HTTPServer(("127.0.0.1", int(sys.argv[2])), H).serve_forever()
PY
cp "$W/hook.py" "$W/prtg_dienst.py"; python3 "$W/prtg_dienst.py" "$W" $HOOKP >/dev/null 2>&1 & sleep 0.3; waitfor "nc -z 127.0.0.1 $HOOKP"
step "1. Ablauf (Modell): Ausfall von 10:10:00 bis 10:17:30, Auslöser 'Down länger als 60 s', Wiederholung alle 180 s"
python3 - <<'PY'
import prtg
ev = [(0, "Up"), (600, "Down"), (1050, "Up")]
for t, text in prtg.benachrichtigungen(ev, ausloeser_s=60, wiederholung_s=180, ende=1100):
    h, r = divmod(36000 + t, 3600); print(f"  {h:02d}:{r//60:02d}:{r%60:02d}  {text}")
PY
step "2. Kurzer Ausfall (45 s) löst nichts aus; mit Auslöser 0 s wird jede Störung gemeldet (keine Entwarnung ohne vorherige Meldung)"
python3 - <<'PY'
import prtg
ev = [(0, "Up"), (600, "Down"), (645, "Up")]
print("  Auslöser 60 s:", prtg.benachrichtigungen(ev, ausloeser_s=60, ende=700) or "keine Nachricht")
print("  Auslöser  0 s:", [t for _, t in prtg.benachrichtigungen(ev, ausloeser_s=0, ende=700)])
PY
step "3. Eskalation: Stufe 1 nach 60 s an das Team, Stufe 2 nach 900 s an die Leitung (Ausfall 20 Minuten)"
python3 - <<'PY'
import prtg
ev = [(0, "Up"), (600, "Down"), (1800, "Up")]
for t, text in prtg.benachrichtigungen(ev, ausloeser_s=60, eskalation_s=900, ende=1900): print(f"  +{t-600:5d} s nach Ausfallbeginn  {text}")
PY
step "4. Zustellung echt: Webhook-Aufruf mit JSON an den lokalen Empfänger (Inhalt mit Platzhaltern wie im Lehrplan beschrieben; Platzhalternamen nicht bestätigt)"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST -H 'Content-Type: application/json' -d '{"sensor":"HTTP srv01","status":"Down","nachricht":"Statuscode 500"}' http://127.0.0.1:$HOOKP/
cat "$W/hook.log"
step "5. Empfänger nicht erreichbar: der Versand schlägt fehl (curl-Fehlercode 7); die Meldung geht verloren, wenn niemand Fehlversuche überwacht"
cmd curl -s -m 2 -o /dev/null -X POST -d x http://127.0.0.1:18299/ ; echo "Rückgabewert: $?"
step "6. Regel für Sinn und Zahl: Benachrichtigungen je Ausfall bei 40 Sensoren eines Geräts - ohne und mit Abhängigkeit (Modul 6)"
python3 - <<'PY'
print("  ohne Abhängigkeit: 40 Sensoren melden Down  ->  40 Nachrichten")
print("  mit Abhängigkeit (Ping als Eltern-Sensor): 1 Nachricht, 39 Sensoren pausiert")
PY
