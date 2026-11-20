#!/usr/bin/env bash
# Modul 8: Aufbewahrung, Datenschutz und Betrieb. Echt: logrotate, find/touch, rsyslog mit mmanon (IP-Anonymisierung), sha256sum, Python. Rechtliche Hinweise sind NICHT geprüft.
. "$(dirname "$0")/../lab.sh"
lab_up; L="$W/logs.jsonl"; python3 "$HERE/gen_logs.py" "$L" >/dev/null
step "1. Rotation mit logrotate: bis zu 3 alte Dateien, komprimiert, Rotation erzwungen (4-mal)"
mkdir -p "$W/app"; cat > "$W/rotate.conf" <<C
$W/app/app.log {
    rotate 3
    compress
    nodateext
    missingok
    notifempty
}
C
for i in 1 2 3 4; do echo "Inhalt Lauf $i" > "$W/app/app.log"; logrotate -s "$W/rotate.state" -f "$W/rotate.conf"; done
echo "Dateien: $(ls "$W/app" | tr '\n' ' ')"
echo "Älteste noch vorhandene Datei enthält: $(zcat "$W/app/app.log.3.gz")  (Lauf 1 ist gelöscht)"
echo "Trockenlauf (-d): zeigt, was logrotate tun würde, ohne etwas zu ändern (Auszug):"; echo "neu" > "$W/app/app.log"
logrotate -d -s "$W/rotate.state" "$W/rotate.conf" 2>&1 | grep -E "considering|rotating|log does not need" | sed -E 's#/tmp/p19#…#; s/^ *//' | head -2
echo "Fehlerbild: unbekannte Direktive:"; printf '%s/app/app.log {\n  rotiere 3\n}\n' "$W" > "$W/kaputt.conf"; logrotate -d -s "$W/rotate.state" "$W/kaputt.conf" 2>&1 | grep -iE "unknown|error" | sed -E 's#/tmp/p19#…#' | head -2
step "2. Aufbewahrungsfrist: Dateien älter als 30 Tage finden (Trockenlauf) und löschen"
mkdir -p "$W/arch"; for d in 5 20 31 45 90; do touch -d "$d days ago" "$W/arch/log-vor-${d}-tagen.gz"; done
echo "Treffer (älter als 30 Tage):"; find "$W/arch" -name '*.gz' -mtime +30 -printf '  %f\n' | sort
find "$W/arch" -name '*.gz' -mtime +30 -delete; echo "Übrig: $(ls "$W/arch" | sort | tr '\n' ' ')"
step "3. Pseudonymisierung: Adressen und Benutzer durch einen Schlüssel-Hash ersetzen (gleiche Eingabe gleicher Wert)"
python3 - "$L" <<'PY'
import hmac, hashlib, json, sys
def pseudo(wert, geheim): return "p_" + hmac.new(geheim, wert.encode(), hashlib.sha256).hexdigest()[:10]
a = b"schluessel-der-uebung"; b = b"anderer-schluessel"
ev = [json.loads(l) for l in open(sys.argv[1])]; ips = sorted({e["ip"] for e in ev if "ip" in e})
print(f"  Adressen im Bestand: {len(ips)}; gleiche Adresse, gleicher Wert: {pseudo(ips[0], a) == pseudo(ips[0], a)}")
print(f"  verschiedene Adressen, verschiedene Werte: {len({pseudo(i, a) for i in ips}) == len(ips)}; anderer Schlüssel, anderer Wert: {pseudo(ips[0], a) != pseudo(ips[0], b)}")
ev99 = [e for e in ev if e.get("ip") == "10.18.0.99" and e.get("ereignis") == "anmeldung_fehler"]
print(f"  Auswertung bleibt möglich: {len({pseudo(e['ip'], a) for e in ev99})} Pseudonym für alle {len(ev99)} Fehlschläge der Angriffsquelle")
print("  Beispiel:", json.dumps({"ip": pseudo("10.18.0.99", a), "benutzer": pseudo("ben", a)}))
PY
step "4. Anonymisierung beim Empfang: rsyslog-Modul mmanon setzt die letzten 8 Bit einer IPv4-Adresse auf 0"
mkdir -p "$W/s"; cat > "$W/s.conf" <<C
global(localHostname="log01" workDirectory="$W/s")
module(load="imudp")
module(load="mmanon")
input(type="imudp" address="127.0.0.1" port="$UDPS")
template(name="t" type="string" string="%msg%\n")
*.* action(type="mmanon" ipv4.enable="on" ipv4.mode="zero" ipv4.bits="8")
*.* action(type="omfile" file="$W/s/anon.log" template="t")
C
rsyslogd -N1 -f "$W/s.conf" 2>&1 | tail -1
rsyslogd -f "$W/s.conf" -i "$W/s.pid" -n >"$W/s.out" 2>&1 & waitfor "[ -s $W/s.pid ]"; sleep 1
logger -n 127.0.0.1 -P $UDPS -d --rfc3164 -t sshd "Failed password for ben from 10.18.0.99 port 51234 ssh2"
logger -n 127.0.0.1 -P $UDPS -d --rfc3164 -t fw "DENY tcp 10.18.0.77 -> 10.18.0.10:22"
warte_zeilen "$W/s/anon.log" 2; sed 's/^ //; s/^/  /' "$W/s/anon.log" | sort
step "5. Unverändertheit nachweisen: Hash-Kette (jede Zeile enthält den Hash der vorigen) und Manipulation erkennen"
python3 - "$L" "$W" <<'PY'
import hashlib, json, sys
def kette(zeilen):
    h = "0" * 64; aus = []
    for z in zeilen: h = hashlib.sha256((h + z).encode()).hexdigest(); aus.append(h)
    return aus
z = [l.rstrip("\n") for l in open(sys.argv[1])][:1000]; k = kette(z)
print(f"  Kette über {len(z)} Zeilen, letzter Hash beginnt mit {k[-1][:12]}")
z2 = list(z); z2[499] = z2[499].replace("srv01", "srvXX"); k2 = kette(z2)
erste = next(i for i in range(len(k)) if k[i] != k2[i])
print(f"  Eine einzige Zeile (Nr. 500) geändert: erste abweichende Prüfsumme ab Zeile {erste + 1}; Zeilen davor unverändert: {k[:erste] == k2[:erste]}")
print(f"  Auch der Endhash ändert sich: {k[-1] != k2[-1]}")
PY
echo "  sha256sum der Logdatei (Dateinachweis): $(sha256sum "$L" | cut -c1-16)…"
step "6. Speicherbedarf abschätzen aus dem gemessenen Mittel einer Zeile"
python3 - "$L" <<'PY'
import sys, os
n = sum(1 for _ in open(sys.argv[1])); b = os.path.getsize(sys.argv[1]); mittel = b / n
print(f"  Bestand: {n} Ereignisse, {b/1024:.0f} KiB, im Mittel {mittel:.0f} Byte je Ereignis")
rechner, ev_tag, tage, komp = 100, n / 3, 90, 0.1
tag = rechner * ev_tag * mittel
print(f"  Annahme: {rechner} Rechner mit je {ev_tag:.0f} Ereignissen am Tag (Bestand geteilt durch seine 3 Rechner), {tage} Tage Aufbewahrung, Verdichtung auf {int(komp*100)} % (Annahme)")
print(f"  Rohdaten je Tag: {tag/1e6:.1f} MB; für {tage} Tage roh: {tag*tage/1e9:.1f} GB; mit Verdichtung: {tag*tage*komp/1e9:.2f} GB (ohne Index und Replikate)")
PY
step "7. Datenschutz-Inventur: welche Felder können Personen betreffen? (Einordnung als Annahme; keine Rechtsberatung, nicht geprüft)"
python3 - "$L" <<'PY'
import json, sys, collections
c = collections.Counter(); 
for l in open(sys.argv[1]): c.update(json.loads(l).keys())
bez = {"ip": "IP-Adresse (kann personenbezogen sein)", "quelle": "IP-Adresse", "benutzer": "Benutzername", "nachricht": "Freitext (kann beides enthalten)"}
for f in ("benutzer", "ip", "quelle", "nachricht"): print(f"  {f:10s} in {c[f]:4d} Ereignissen: {bez[f]}")
PY
step "8. Abschlussprojekt – Abnahmeprüfung (je Prüfpunkt OK/FEHLER)"
chk() { if eval "$2" >/dev/null 2>&1; then echo "OK      $1"; else echo "FEHLER  $1"; fi; }
chk "rsyslog-Konfiguration gültig"            "rsyslogd -N1 -f $W/s.conf"
chk "Empfang und Anonymisierung vorhanden"    "grep -q '10.18.0.0' $W/s/anon.log && ! grep -q '10.18.0.99' $W/s/anon.log"
chk "Rotation hat 3 alte Dateien behalten"    "[ -f $W/app/app.log.3.gz ] && [ ! -f $W/app/app.log.4.gz ]"
chk "Aufbewahrung: nichts über 30 Tage übrig" "[ -z \"\$(find $W/arch -mtime +30)\" ]"
chk "Logdatei hat Nachweis-Hash"              "[ -n \"\$(sha256sum $L)\" ]"
chk "absichtlich falsch: Datei fehlt"         "[ -f $W/gibt-es-nicht.log ]"
