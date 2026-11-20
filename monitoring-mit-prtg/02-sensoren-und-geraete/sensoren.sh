#!/usr/bin/env bash
# Modul 2: Sensoren und Geräte. Echt: TCP-, HTTP- und Ping-ähnliche Prüfungen gegen einen lokalen Python-HTTP-Server. Modell: Statuslogik und Sensorzählung (prtg.py).
. "$(dirname "$0")/../lab.sh"
lab_up
export PYTHONPATH="$HERE"
python3 -m http.server $HTTPP --bind 127.0.0.1 --directory "$W" >/dev/null 2>&1 &
sleep 0.2; echo ok > "$W/index.html"; waitfor "nc -z 127.0.0.1 $HTTPP"
step "1. Sensorarten nach Zweck (Modell; Namen der PRTG-Sensoren sind nicht bestätigt)"
cat <<'TXT'
  Erreichbarkeit  : Ping                  -> ist das Gerät da?
  Dienst          : Port (TCP)            -> antwortet der Dienst?
  Anwendung       : HTTP                  -> richtiger Statuscode, Antwortzeit?
  Werte           : SNMP, WMI, SSH        -> CPU, Speicher, Platte, Schnittstellen (Modul 3)
  Eigene Werte    : Skript-Sensor         -> Modul 7
TXT
step "2. Echte Prüfungen gegen 127.0.0.1: Port offen, HTTP-Statuscode, falscher Port, falscher Pfad"
python3 - <<'PY'
import socket, urllib.request, urllib.error
def tcp(p):
    s = socket.socket(); s.settimeout(0.5); r = s.connect_ex(("127.0.0.1", p)); s.close(); return r == 0
def http(pfad):
    try:
        r = urllib.request.urlopen(f"http://127.0.0.1:18201{pfad}", timeout=1); return r.status
    except urllib.error.HTTPError as e: return e.code
for n, w in [("Port 18201", tcp(18201)), ("Port 18299 (nichts dahinter)", tcp(18299)), ("HTTP /", http("/")), ("HTTP /gibt-es-nicht", http("/gibt-es-nicht"))]:
    print(f"  {n:30s} -> {w}")
PY
step "3. Statuslogik (Modell): Messwert gegen Grenzen, Antwortzeit 120 ms Warnung ab 100, Fehler ab 500"
python3 - <<'PY'
import prtg
for ms in (40, 100, 101, 500, 501): print(f"  {ms:4d} ms -> {prtg.status(ms, warn=100, fehler=500)}")
print("  keine Antwort ->", prtg.status(0, warn=100, fehler=500, ok=False))
PY
step "4. Ein Fehlversuch genügt nicht: 'Down (teilweise)', bis zwei Messungen in Folge fehlschlagen (Modell, einstellbar)"
python3 - <<'PY'
import prtg
reihe = ["Up", "Down", "Up", "Down", "Down", "Down", "Up"]
for t, roh, gem in prtg.lauf(reihe, scan=60, down_nach=2): print(f"  t={t:3d} s  gemessen {roh:4s}  gemeldet {gem}")
PY
step "5. Sensorbudget: Geräte mit Sensoren gegen die Grenze der Gratisstufe (100, Stand 20.11.2026)"
python3 - <<'PY'
import prtg
geraete = {"srv01": {"Ping": 1, "Port": 2, "HTTP": 1, "SNMP": 12}, "srv02": {"Ping": 1, "SNMP": 12}, "fw01": {"Ping": 1, "SNMP": 20},
           "sw01": {"Ping": 1, "SNMP (Ports)": 48}, "sw02": {"Ping": 1, "SNMP (Ports)": 48}}
je, ges = prtg.sensoren_zaehlen(geraete)
for g, n in je.items(): print(f"  {g:6s} {n:3d} Sensoren")
print(f"  gesamt {ges} von {prtg.FREEWARE_LIMIT} -> {'OK' if ges <= prtg.FREEWARE_LIMIT else 'ÜBER DER GRENZE um ' + str(ges - prtg.FREEWARE_LIMIT)}")
sw = {k: v for k, v in geraete.items()}; sw["sw01"] = {"Ping": 1, "SNMP (Ports)": 6}; sw["sw02"] = {"Ping": 1, "SNMP (Ports)": 6}
print("  nur die 6 wichtigen Ports je Switch:", prtg.sensoren_zaehlen(sw)[1], "Sensoren")
PY
