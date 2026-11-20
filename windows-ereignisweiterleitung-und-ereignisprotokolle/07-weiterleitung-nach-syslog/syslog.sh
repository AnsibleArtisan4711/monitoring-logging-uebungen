#!/usr/bin/env bash
# Modul 7 (Priorität 2): Ereignisse im Syslog-Format (RFC-5424-Aufbau, aus Fachwissen) ausgeben und wieder einlesen. Modell mit erfundenen Daten.
. "$(dirname "$0")/../lab.sh"
lab_up; D="$(dirname "$0")/.."
python3 - "$W/events.xml" "$D" "$W/out.syslog" <<'PY'
import sys, re; sys.path.insert(0, sys.argv[2])
from evlib import *
FAC = {'Security': 4, 'System': 3, 'Application': 1}              # Annahme: auth=4, daemon=3, user=1
SEV = {0: 5, 1: 2, 2: 3, 3: 4, 4: 6}                              # Annahme: Level -> Syslog-Schweregrad (0 -> notice, 4 -> informational)
def zeile(e):
    pri = FAC[kanal(e)] * 8 + SEV[int(feld(e, 'Level'))]
    sd = ' '.join('%s="%s"' % (k, v.replace('"', "'")) for k, v in daten(e).items())
    return '<%d>1 %s %s %s - %d [daten %s] ' % (pri, zeit(e).replace('.000Z', 'Z'), host(e), e.xpath('e:System/e:Provider/@Name', namespaces=NS)[0].replace(' ', '_'), eid(e), sd)
ev = lade(sys.argv[1]); z = [zeile(e) for e in ev if eid(e) in (4625, 4740, 4720, 1102, 7045)]
open(sys.argv[3], 'w').write('\n'.join(z) + '\n')
print('\n## 1. Umgesetzte Ereignisse: %d, Beispiele' % len(z))
for l in z[:2] + z[-3:]: print('  ' + l)
print('\n## 2. Priorität = Facility x 8 + Schweregrad (Beispiel Sicherheitsprotokoll, Level 0)')
print('  4 x 8 + 5 = %d' % (4 * 8 + 5))
print('\n## 3. Wieder einlesen: Aufbau prüfen')
muster = re.compile(r'^<(\d+)>1 (\S+) (\S+) (\S+) - (\d+) \[daten (.*)\] $'); ok = 0
for l in open(sys.argv[3]).read().splitlines():
    m = muster.match(l); ok += bool(m)
print('  Zeilen: %d, Aufbau stimmt: %d' % (len(z), ok))
print('\n## 4. Auswertung auf Syslog-Seite: Zeilen je Anwendungsname (Quelle)')
from collections import Counter
for k, n in Counter(muster.match(l).group(4) for l in open(sys.argv[3]).read().splitlines()).most_common(): print('  %-36s %d' % (k, n))
print('\n## 5. Verlust beim Umsetzen')
print('  Der Syslog-Text enthält nur die gewählten Felder (Zeit, Computer, Quelle, ID, Nutzdaten); Felder wie EventRecordID und Kanal gehen verloren.')
PY
step "6. Weiterleitung (nur Text)"
echo "Für die Weiterleitung von Windows-Ereignissen an Syslog-Server gibt es Zusatzprogramme; kein Produkt wurde ausgeführt, keine Version und kein Lizenzmodell wurden geprüft."
