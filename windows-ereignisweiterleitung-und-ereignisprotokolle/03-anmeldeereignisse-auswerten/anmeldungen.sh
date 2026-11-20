#!/usr/bin/env bash
# Modul 3: Anmeldeereignisse auswerten (Sicherheitsprotokoll, erfundene Daten): Fehlversuche je Benutzer und Adresse, Sperre, Zeitfenster.
. "$(dirname "$0")/../lab.sh"
lab_up; D="$(dirname "$0")/.."
python3 - "$W/events.xml" "$D" <<'PY'
import sys; sys.path.insert(0, sys.argv[2])
from evlib import *; from collections import Counter, defaultdict
ev = lade(sys.argv[1]); sec = [e for e in ev if kanal(e) == 'Security']
print('\n## 1. Erfolgreiche und fehlgeschlagene Anmeldungen je Benutzer')
ok = Counter(daten(e)['TargetUserName'] for e in sec if eid(e) == 4624); bad = Counter(daten(e)['TargetUserName'] for e in sec if eid(e) == 4625)
for u in sorted(set(ok) | set(bad)): print('  %-5s erfolgreich %2d  fehlgeschlagen %2d' % (u, ok[u], bad[u]))
print('\n## 2. Fehlschläge nach Anmeldetyp (2 = interaktiv, 3 = Netzwerk: laut Fachwissen)')
for t, n in sorted(Counter(daten(e)['LogonType'] for e in sec if eid(e) == 4625).items()): print('  Typ %s: %d' % (t, n))
print('\n## 3. Fehlschläge nach Quelladresse')
for a, n in Counter(daten(e)['IpAddress'] for e in sec if eid(e) == 4625).most_common(): print('  %-12s %d' % (a, n))
print('\n## 4. Verdacht: mindestens 5 Fehlschläge derselben Adresse innerhalb von 60 Sekunden')
from datetime import datetime
def sek(z): return datetime.strptime(z[:19], '%Y-%m-%dT%H:%M:%S').timestamp()
je = defaultdict(list)
for e in sec:
    if eid(e) == 4625: je[daten(e)['IpAddress']].append(sek(zeit(e)))
for a, l in je.items():
    l.sort(); m = max(sum(1 for y in l if x <= y < x + 60) for x in l)
    print('  %-12s Höchstwert in 60 s: %d -> %s' % (a, m, 'VERDACHT' if m >= 5 else 'unauffällig'))
print('\n## 5. Konto gesperrt (4740): Zeitpunkt nach dem letzten Fehlschlag?')
sp = [e for e in sec if eid(e) == 4740][0]; letzte = max(sek(zeit(e)) for e in sec if eid(e) == 4625 and daten(e)['TargetUserName'] == 'cara')
print('  Sperre von %s auf %s, %d s nach dem letzten Fehlschlag' % (daten(sp)['TargetUserName'], host(sp), sek(zeit(sp)) - letzte))
print('\n## 6. Hinweis')
print('  Schwelle (5 in 60 s) und Zeitfenster sind Beispielwerte, keine Empfehlung.')
PY
