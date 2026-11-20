#!/usr/bin/env bash
# Modul 7: Eigene Sensoren (Skripte). Echt: Skripte, die das Format "EXE/Script Advanced" (XML und JSON) ausgeben, geprüft mit xmllint/jq/Python.
# Das Format stammt aus der Herstellerseite "Custom Sensors" (gelesen am 20.11.2026); gegen PRTG selbst wurde nichts getestet.
. "$(dirname "$0")/../lab.sh"
lab_up
step "1. Ein Skript mit gültiger XML-Antwort und zwei Kanälen (Plattenbelegung in Prozent, Anzahl Dateien); bestätigt sind prtg, result, channel, value, unit, float, limitmaxerror, text, error - limitmaxwarning und limitmode sind nicht bestätigt"
mkdir -p "$W/EXEXML"; cat > "$W/EXEXML/platte.sh" <<'SH'
#!/usr/bin/env bash
pfad=${1:-/}; proz=$(df -P "$pfad" | tail -1 | awk '{gsub("%","",$5); print $5}')
dat=${2:-5}
cat <<XML
<?xml version="1.0" encoding="UTF-8" ?>
<prtg>
  <result><channel>Belegung</channel><value>$proz</value><unit>Percent</unit><limitmaxwarning>80</limitmaxwarning><limitmaxerror>90</limitmaxerror><limitmode>1</limitmode></result>
  <result><channel>Dateien</channel><value>$dat</value><unit>Count</unit></result>
  <text>Pfad $pfad</text>
</prtg>
XML
SH
chmod +x "$W/EXEXML/platte.sh"
"$W/EXEXML/platte.sh" / 7 > "$W/antwort.xml"; xmllint --noout "$W/antwort.xml"; echo "xmllint-Rückgabe: $? (0 = wohlgeformt)"
echo "Kanäle: $(xmllint --xpath 'count(//result)' "$W/antwort.xml"), zweiter Kanal: $(xmllint --xpath 'string(//result[2]/channel)' "$W/antwort.xml")"
step "2. Dieselbe Antwort als JSON (Python), mit Gleitkommawert (float=1) und Einheit"
cat > "$W/EXEXML/antwort.py" <<'PY'
import json, sys
temp = float(sys.argv[1]) if len(sys.argv) > 1 else 21.5
print(json.dumps({"prtg": {"result": [{"channel": "Temperatur", "value": temp, "unit": "Custom", "customunit": "°C", "float": 1, "limitmaxerror": 30, "limitmode": 1}]}}, ensure_ascii=False))
PY
python3 "$W/EXEXML/antwort.py" 21.5 | jq -c '.prtg.result[0] | {channel, value, float}'
python3 "$W/EXEXML/antwort.py" 21.5 | jq -e '.prtg.result | length >= 1' >/dev/null && echo "Prüfung: mindestens ein Kanal -> OK"
step "3. Fehlerantwort: error=1 und text (so meldet ein Skript, dass die Messung selbst scheiterte)"
cat > "$W/EXEXML/fehler.sh" <<'SH'
#!/usr/bin/env bash
[ -d "${1:-/gibt/es/nicht}" ] || { echo '<prtg><error>1</error><text>Verzeichnis fehlt</text></prtg>'; exit 0; }
echo '<prtg><result><channel>ok</channel><value>1</value></result></prtg>'
SH
chmod +x "$W/EXEXML/fehler.sh"
"$W/EXEXML/fehler.sh" /gibt/es/nicht | xmllint --format - | tail -4
step "4. Prüfer für eigene Skripte: Kanalnamen eindeutig, value ist eine Zahl, mindestens ein Kanal (Python)"
cat > "$W/pruefer.py" <<'PY'
import sys, json, re
import xml.etree.ElementTree as ET
t = sys.stdin.read().strip(); f = []
try:
    if t.startswith("{"):
        d = json.loads(t)["prtg"]; erg = d.get("result", []); fehler = d.get("error")
        namen = [r.get("channel") for r in erg]; werte = [r.get("value") for r in erg]
    else:
        w = ET.fromstring(t); erg = w.findall("result"); fehler = (w.findtext("error"))
        namen = [r.findtext("channel") for r in erg]; werte = [r.findtext("value") for r in erg]
except Exception as e:
    print("FEHLER nicht lesbar:", type(e).__name__); sys.exit(1)
if fehler not in (None, "0", 0): print("Meldung des Skripts: error=" + str(fehler)); sys.exit(0)
if not erg: f.append("kein Kanal")
if len(set(namen)) != len(namen): f.append("Kanalnamen doppelt")
if any(n in (None, "") for n in namen): f.append("Kanalname fehlt")
for v in werte:
    if v is None or not re.fullmatch(r"-?[0-9]+(\.[0-9]+)?", str(v)): f.append(f"value keine Zahl: {v!r}")
print("OK" if not f else "FEHLER " + "; ".join(f))
PY
for n in "gut" "doppelt" "text" "leer" "kaputt"; do
  case $n in
    gut) a='<prtg><result><channel>a</channel><value>1</value></result><result><channel>b</channel><value>2.5</value></result></prtg>';;
    doppelt) a='<prtg><result><channel>a</channel><value>1</value></result><result><channel>a</channel><value>2</value></result></prtg>';;
    text) a='<prtg><result><channel>a</channel><value>viel</value></result></prtg>';;
    leer) a='<prtg></prtg>';;
    kaputt) a='<prtg><result>';;
  esac
  printf '  %-8s -> ' "$n"; echo "$a" | python3 "$W/pruefer.py"
done
step "5. Zeitlimit: ein Skript, das zu lange braucht, wird abgebrochen (hier 'timeout 1' als Ersatz für die Zeitüberschreitung des Sensors)"
cat > "$W/EXEXML/langsam.sh" <<'SH'
#!/usr/bin/env bash
sleep 3; echo '<prtg><result><channel>x</channel><value>1</value></result></prtg>'
SH
chmod +x "$W/EXEXML/langsam.sh"
timeout 1 "$W/EXEXML/langsam.sh"; echo "Rückgabewert: $? (124 = Zeitlimit überschritten; der Sensor meldet dann einen Fehler)"
step "6. Ablage und Aufruf (Text): wo das Skript liegen muss"
cat <<'TXT'
  Windows-Probe : Skriptdatei im Unterordner \Custom Sensors\EXEXML des PRTG-Programmordners; erlaubte Endungen .bat .cmd .exe .ps1 .vbs (Stand 20.11.2026)
  Linux-Ziel    : Sensor "SSH Script Advanced", Skript auf dem Ziel unter /var/prtg/scriptsxml (Stand 20.11.2026); gleiche XML/JSON-Ausgabe
  Cluster       : Datei auf jedem Knoten ablegen; Zeitlimit höchstens 900 s
  Fehlersuche   : Option "Ergebnis speichern" aktivieren, dann die Rohausgabe lesen
  Menünamen in PRTG: nicht bestätigt
TXT
