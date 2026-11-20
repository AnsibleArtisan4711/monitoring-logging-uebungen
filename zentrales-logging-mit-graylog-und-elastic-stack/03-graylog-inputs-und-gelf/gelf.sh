#!/usr/bin/env bash
# Modul 3: Graylog – Aufbau, Inputs und das Nachrichtenformat GELF. MODELL in Python (Graylog, MongoDB und OpenSearch/Elasticsearch laufen hier NICHT).
# Echt sind nur die UDP-Datagramme auf 127.0.0.1 und die Komprimierung (gzip/zlib) – gegen ein echtes Graylog wurde nichts getestet.
. "$(dirname "$0")/../lab.sh"
lab_up
export PYTHONPATH="$HERE"
step "1. Eine gültige GELF-Nachricht (Pflichtfelder: version, host, short_message; Zusatzfelder mit Unterstrich)"
python3 - <<'PY'
import json, gelf
m = {"version": "1.1", "host": "srv02", "short_message": "Failed password for ben from 10.18.0.99", "timestamp": 1793019720.5, "level": 6,
     "_programm": "sshd", "_benutzer": "ben", "_ip": "10.18.0.99"}
print(json.dumps(m, ensure_ascii=False)); print("Fehler:", gelf.pruefe(m) or "keine")
PY
step "2. Ungültige Nachrichten und die Fehlerliste des Prüfers"
python3 - <<'PY'
import gelf
fall = {"ohne short_message": {"version": "1.1", "host": "srv01"},
        "falsche Version": {"version": "1.0", "host": "srv01", "short_message": "x"},
        "Level 9": {"version": "1.1", "host": "srv01", "short_message": "x", "level": 9},
        "Zusatzfeld ohne Unterstrich": {"version": "1.1", "host": "srv01", "short_message": "x", "benutzer": "ben"},
        "Zusatzfeld _id": {"version": "1.1", "host": "srv01", "short_message": "x", "_id": 5},
        "Zusatzfeld mit Liste": {"version": "1.1", "host": "srv01", "short_message": "x", "_liste": [1, 2]}}
for n, m in fall.items(): print(f"  {n:30s} -> {'; '.join(gelf.pruefe(m))}")
PY
step "3. Größe der Datagramme: unkomprimiert, gzip, zlib (eine längere Nachricht mit Wiederholungen)"
python3 - <<'PY'
import gelf
m = {"version": "1.1", "host": "srv01", "short_message": "GET /api/status 500", "full_message": "Fehler in der Anwendung bei der Verarbeitung der Anfrage. " * 60, "level": 3, "_status": 500}
r = len(gelf.kodiere(m)); g = len(gelf.kodiere(m, "gzip")); z = len(gelf.kodiere(m, "zlib"))
print(f"  roh {r} Byte, gzip {g} Byte, zlib {z} Byte; gzip kleiner als ein Fünftel: {g < r/5}")
print("  Rückweg gzip gleich Original:", gelf.dekodiere(gelf.kodiere(m, 'gzip')) == m, "| zlib:", gelf.dekodiere(gelf.kodiere(m, 'zlib')) == m)
PY
step "4. Ein Modell-Input über UDP (127.0.0.1:12201): einfache, komprimierte und zerlegte Datagramme; ein verlorener Teil"
python3 - <<'PY'
import socket, threading, time, gelf
S = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); S.bind(("127.0.0.1", 12201)); S.settimeout(0.5)
sam = gelf.Sammler(); fertig = []
def lauf():
    while True:
        try: p, _ = S.recvfrom(65535)
        except socket.timeout:
            if stop: return
            continue
        m = sam.paket(p)
        if m: fertig.append(m)
stop = False; t = threading.Thread(target=lauf); t.start()
C = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
def senden(b): C.sendto(b, ("127.0.0.1", 12201)); time.sleep(0.05)
klein = {"version": "1.1", "host": "srv01", "short_message": "klein"}
gross = {"version": "1.1", "host": "srv01", "short_message": "gross", "full_message": "".join(chr(33 + (i * 7) % 90) for i in range(4000))}
senden(gelf.kodiere(klein)); senden(gelf.kodiere(klein, "gzip")); senden(gelf.kodiere(klein, "zlib"))
teile = gelf.chunks(gelf.kodiere(gross)); print(f"  große Nachricht: {len(gelf.kodiere(gross))} Byte in {len(teile)} Teilen (Teil 0 beginnt mit {teile[0][:2].hex()})")
for p in reversed(teile): senden(p)           # Reihenfolge umgekehrt: trotzdem vollständig
verlust = gelf.chunks(gelf.kodiere(gross)); verlust.pop(1)
for p in verlust: senden(p)                   # ein Teil fehlt: Nachricht bleibt unvollständig
time.sleep(0.5); stop = True; t.join()
print("  angekommen:", [m["short_message"] for m in fertig])
print("  unvollständige Nachrichten im Speicher:", len(sam.offen))
print("  große Nachricht unverändert:", any(m.get("full_message") == gross["full_message"] for m in fertig))
PY
step "5. Eine Syslog-Zeile (Modul 2) und ein erfundenes Windows-Ereignis nach GELF umsetzen"
python3 - <<'PY'
import json, gelf
sys_ = {"host": "lin01", "programm": "webapp", "severity": "err", "facility": "local4", "nachricht": "Datenbank nicht erreichbar"}
lv = {"emerg": 0, "alert": 1, "crit": 2, "err": 3, "warning": 4, "notice": 5, "info": 6, "debug": 7}
g1 = {"version": "1.1", "host": sys_["host"], "short_message": sys_["nachricht"], "level": lv[sys_["severity"]], "_programm": sys_["programm"], "_facility": sys_["facility"]}
win = {"Computer": "win01", "EventID": 4625, "Level": 0, "Channel": "Security", "TargetUserName": "ben", "IpAddress": "10.18.0.99", "LogonType": 3}
g2 = {"version": "1.1", "host": win["Computer"], "short_message": f"Ereignis {win['EventID']} im Kanal {win['Channel']}", "level": 6, "_ereignis_id": win["EventID"], "_kanal": win["Channel"], "_benutzer": win["TargetUserName"], "_ip": win["IpAddress"], "_anmeldetyp": win["LogonType"]}
for g in (g1, g2): print(" ", json.dumps(g, ensure_ascii=False), "->", "gültig" if not gelf.pruefe(g) else gelf.pruefe(g))
PY
step "6. Aufbau von Graylog laut Fachwissen (NICHT ausgeführt, Versionen und Lizenzmodell mit Stand prüfen)"
cat <<'T'
  Graylog-Server (Eingänge, Streams, Pipelines, Weboberfläche) + MongoDB (Konfiguration, Benutzer) + Suchindex (OpenSearch oder Elasticsearch, Nachrichten).
  Eingänge (Inputs): unter anderem GELF (UDP/TCP), Syslog, Beats. Standardports und Menünamen: nicht bestätigt.
  Lizenzmodell und unterstützte Versionen der Bausteine ändern sich: vor einem Einsatz auf der Herstellerseite mit Datum prüfen (hier nicht geprüft).
T
