#!/usr/bin/env bash
# Modul 1: Aufbau und Installation. PRTG läuft hier NICHT. Echt ist nur die Vorabprüfung (Python, TCP-Ports auf 127.0.0.1); Schwellenwerte sind Übungswerte.
. "$(dirname "$0")/../lab.sh"
lab_up
export PYTHONPATH="$HERE"
step "1. Bausteine und Wege (Modell der Architektur; Namen nach Lehrplan, Hersteller-Details nicht geprüft)"
python3 - <<'PY'
kette = [("Browser (Web-Oberfläche)", "HTTPS", "PRTG Core Server"),
         ("PRTG Core Server", "TCP, Standard 23560 (nicht bestätigt)", "Probe (lokal oder remote)"),
         ("Probe", "SNMP/WMI/SSH/HTTP/Ping", "überwachtes Gerät"),
         ("PRTG Core Server", "SMTP", "Mailserver (Benachrichtigung)")]
for a, w, b in kette: print(f"  {a:28s} --{w:38s}--> {b}")
print("  Sensoren laufen auf der Probe; Konfiguration und Messdaten liegen auf dem Core Server.")
PY
step "2. Vorabprüfung des Servers (Übungsschwellen: 8 GB RAM, 60 GB frei, 64-Bit-Windows; Ports 80 und 443 frei)"
python3 - <<'PY'
def pruefe(ram_gb, frei_gb, os_name, belegt):
    f = []
    if ram_gb < 8: f.append(f"RAM {ram_gb} GB < 8 GB")
    if frei_gb < 60: f.append(f"nur {frei_gb} GB frei < 60 GB")
    if "Windows" not in os_name: f.append(f"Betriebssystem {os_name}: PRTG braucht Windows")
    for p in (80, 443):
        if p in belegt: f.append(f"Port {p} belegt")
    return f
fall = {"Labor-VM ok": (8, 120, "Windows Server 2022", []),
        "zu wenig RAM": (4, 120, "Windows Server 2022", []),
        "Linux-VM": (16, 200, "Ubuntu 24.04", []),
        "Port 443 belegt (IIS)": (8, 120, "Windows Server 2022", [443])}
for n, a in fall.items():
    r = pruefe(*a); print(f"  {n:24s} -> {'OK' if not r else 'FEHLER: ' + '; '.join(r)}")
PY
step "3. Echte Prüfung auf diesem Rechner: ist Port 443 und Port 23560 auf 127.0.0.1 frei? (frei = Verbindung abgelehnt)"
python3 - <<'PY'
import socket
for p in (443, 23560):
    s = socket.socket(); s.settimeout(0.5)
    print(f"  127.0.0.1:{p} ->", "belegt" if s.connect_ex(("127.0.0.1", p)) == 0 else "frei"); s.close()
PY
step "4. Reihenfolge der Installation (Checkliste, nicht ausgeführt)"
cat <<'TXT'
  1. VM am privaten Switch (Hyper-V) mit fester Adresse, Namensauflösung, Zeit (NTP) prüfen
  2. Installationsprogramm von der Herstellerseite laden, Prüfsumme/Signatur prüfen (Quelle und Version notieren)
  3. Installieren, Administrator-Kennwort setzen, Web-Oberfläche per HTTPS aufrufen
  4. Lizenz prüfen: Test 30 Tage, danach Freeware bis 100 Sensoren (Stand 20.11.2026, Handbuchseite Available Licenses)
  5. Mail-Server (SMTP) für Benachrichtigungen eintragen und Testmail senden
  6. Erstes Gerät anlegen, Sensorzahl vorher planen (Modul 2 und 8)
TXT
