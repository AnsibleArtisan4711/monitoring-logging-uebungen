#!/usr/bin/env bash
# Modul 8: Lizenzmodell der Gratisstufe und Betrieb. Echt: Rechnen mit Sensorzahlen und Datum, tar-Sicherung eines Modell-Konfigurationsordners, Prüfsummen, Abnahmeliste.
# Lizenzangaben (Test 30 Tage, danach Freeware bis 100 Sensoren) nach der Handbuchseite "Available Licenses", gelesen am 20.11.2026 - Stand prüfen, Bedingungen können sich ändern.
. "$(dirname "$0")/../lab.sh"
lab_up
export PYTHONPATH="$HERE"
step "1. Die Stufen (Stand 20.11.2026, Handbuchseite Available Licenses)"
cat <<'TXT'
  Test      : 30 Tage, unbegrenzt viele Sensoren, alle Sensorarten
  Freeware  : bis 100 Sensoren, alle Sensorarten, für private und gewerbliche Nutzung; nach dem Test fällt PRTG auf diese Stufe zurück
  Kommerziell: Sensorzahl nach Lizenz (genaue Zahlen und Preise: nicht bestätigt, Herstellerportal)
  Offen      : was bei Überschreitung genau passiert (Sensoren pausiert? Ablehnung?) - nicht bestätigt, vor dem Einsatz nachlesen
TXT
step "2. Ende des Tests berechnen (Installation am 2026-11-20, 30 Tage) und Restzeit zu einem Prüftag"
python3 - <<'PY'
import datetime as d, prtg
inst = d.date(2026, 11, 20); ende = inst + d.timedelta(days=prtg.TRIAL_TAGE)
print("  Testende (Installationstag + 30 Tage, genaue Zählweise nicht bestätigt):", ende.isoformat())
for tag in (d.date(2026, 12, 1), d.date(2026, 12, 19), d.date(2026, 12, 21)):
    rest = (ende - tag).days
    print(f"  am {tag}: " + (f"noch {rest} Tag(e) Test" if rest > 0 else "Test vorbei -> Freeware, höchstens 100 Sensoren"))
PY
step "3. Sensorbudget planen: Zielzustand mit Ampel (grün bis 80, gelb bis 100, rot darüber; Ampelgrenzen sind Übungswerte)"
python3 - <<'PY'
import prtg
plan = {"Kerngeräte (Ping+SNMP kompakt)": 22, "Server (6 Sensoren je Server, 8 Server)": 48, "Webdienste (HTTP, Port)": 12, "Eigene Skripte": 8}
ges = 0
for n, z in plan.items(): ges += z; print(f"  {n:42s} {z:3d}   Summe {ges:3d}")
def ampel(n, g=prtg.FREEWARE_LIMIT): return "grün" if n <= 0.8 * g else "gelb" if n <= g else "rot"
print(f"  gesamt {ges} von {prtg.FREEWARE_LIMIT} -> {ampel(ges)}; freie Reserve {prtg.FREEWARE_LIMIT - ges}")
print("  mit 2 weiteren Servern (je 6):", ampel(ges + 12), f"({ges + 12} Sensoren)")
PY
step "4. Sicherung (Modell): Konfigurationsordner mit tar sichern, Prüfsumme, Wiederherstellung, Vergleich"
mkdir -p "$W/konfig" "$W/rueck"; for i in 1 2 3; do echo "sensor $i intervall 60" > "$W/konfig/sensor$i.cfg"; done
tar -C "$W" -czf "$W/sicherung.tar.gz" konfig; tar -tzf "$W/sicherung.tar.gz" | sort
( cd "$W/konfig" && sha256sum *.cfg ) | sha256sum | cut -c1-12 > "$W/vorher.txt"
tar -C "$W/rueck" -xzf "$W/sicherung.tar.gz"
( cd "$W/rueck/konfig" && sha256sum *.cfg ) | sha256sum | cut -c1-12 > "$W/nachher.txt"
cmp -s "$W/vorher.txt" "$W/nachher.txt" && echo "Wiederherstellung: Prüfsummen gleich" || echo "Wiederherstellung: ABWEICHUNG"
echo "Hinweis: Ort der echten PRTG-Daten und die Sicherungsfunktion von PRTG: nicht bestätigt; Konfiguration und Datenordner getrennt sichern."
step "5. Abnahmeliste (eine Zeile ist absichtlich ein FEHLER)"
python3 - <<'PY'
pruefungen = [("Web-Oberfläche per HTTPS erreichbar", True), ("Testmail zugestellt", True), ("Sensorzahl <= 100", True),
              ("Abhängigkeit Switch -> Server gesetzt", True), ("Eigener Skriptsensor liefert gültiges XML", True), ("Sicherung der Konfiguration wiederhergestellt und geprüft", False)]
for n, ok in pruefungen: print(f"  {'OK    ' if ok else 'FEHLER'} {n}")
print(f"  Ergebnis: {sum(o for _, o in pruefungen)} von {len(pruefungen)} bestanden")
PY
