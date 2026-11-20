#!/usr/bin/env bash
# Modul 2: Ereignisabfragen im XPath-Stil (Select-Ausdrücke wie in Windows-Abfragen). Modell mit lxml: das Verhalten von Windows wurde nicht geprüft.
. "$(dirname "$0")/../lab.sh"
lab_up; D="$(dirname "$0")/.."
abf() { python3 - "$W/events.xml" "$D" "$1" <<'PY'
import sys; sys.path.insert(0, sys.argv[2])
from evlib import *
r = abfrage(sys.argv[3], sys.argv[1]); print('Treffer: %d' % len(r))
for e in r[:3]: print('  %s %-18s %5d %s' % (zeit(e)[11:19], host(e), eid(e), daten(e).get('TargetUserName', '')))
PY
}
step "1. Nach Ereignis-ID: *[System[(EventID=4625)]]"
abf '*[System[(EventID=4625)]]'
step "2. ID-Liste mit oder: Anmeldung gescheitert oder Konto gesperrt"
abf '*[System[(EventID=4625 or EventID=4740)]]'
step "3. Nach Computer: *[System[Computer='srv01.example.org']]"
abf "*[System[Computer='srv01.example.org']]"
step "4. Kombination: Anmeldefehler auf srv01 UND Benutzer cara (Nutzdaten)"
abf "*[System[(EventID=4625) and Computer='srv01.example.org'] and EventData[Data[@Name='TargetUserName']='cara']]"
step "5. Zeitraum: XPath 1.0 vergleicht keine Zeichenketten mit < und >, der Ausdruck liefert im Modell keine Treffer"
abf "*[System[TimeCreated[@SystemTime>='2026-12-01T11:00:00']]]"
echo "Deshalb wird der Zeitraum im Modell in Python geprüft (zeit(e) als Text, gleiche Form):"
python3 - "$W/events.xml" "$D" <<'PY'
import sys; sys.path.insert(0, sys.argv[2])
from evlib import *
r = [e for e in lade(sys.argv[1]) if '2026-12-01T11:00:00' <= zeit(e) < '2026-12-01T12:00:00']
print('Treffer: %d (IDs %s)' % (len(r), sorted(set(eid(e) for e in r))))
PY
echo "Windows kennt für Zeiträume die Funktion timediff (Fachwissen, nicht geprüft)."
step "5b. Nach Stufe: Level=4 (laut Fachwissen: Information)"
abf '*[System[Level=4]]' | sed -n 1p
step "6. Mit wevtutil (Text, nicht ausgeführt, Befehl aus Fachwissen)"
cat <<'T'
wevtutil qe Security /q:"*[System[(EventID=4625)]]" /c:5 /f:text
T
