#!/usr/bin/env bash
# Modul 8: Erkennungsregeln und Abschlussprojekt auf erfundenen Ereignissen: Regeln als Daten, Auswertung, Bericht.
. "$(dirname "$0")/../lab.sh"
lab_up; D="$(dirname "$0")/.."
python3 - "$W/events.xml" "$D" <<'PY'
import sys; sys.path.insert(0, sys.argv[2])
from evlib import *
from datetime import datetime
from collections import defaultdict
ev = lade(sys.argv[1]); sek = lambda z: datetime.strptime(z[:19], '%Y-%m-%dT%H:%M:%S').timestamp()
def regel_serie(e, n=5, fenster=60):
    je = defaultdict(list); [je[daten(x)['IpAddress']].append(sek(zeit(x))) for x in e if eid(x) == 4625 and daten(x)['IpAddress'] != '-']
    return ['Serie von Anmeldefehlern von %s (%d in %d s)' % (a, max(sum(1 for y in l if x <= y < x + fenster) for x in l), fenster) for a, l in je.items() if max(sum(1 for y in l if x <= y < x + fenster) for x in l) >= n]
def regel_id(e, i, text): return ['%s auf %s um %s' % (text, host(x), zeit(x)[11:19]) for x in e if eid(x) == i]
REGELN = [
  ('R1', 'hoch', lambda e: regel_serie(e)),
  ('R2', 'mittel', lambda e: regel_id(e, 4740, 'Konto gesperrt')),
  ('R3', 'hoch', lambda e: regel_id(e, 1102, 'Überwachungsprotokoll gelöscht')),
  ('R4', 'mittel', lambda e: regel_id(e, 7045, 'Neuer Dienst installiert')),
  ('R5', 'niedrig', lambda e: regel_id(e, 4720, 'Neues Benutzerkonto')),
]
print('\n## 1. Regeln auf %d Ereignisse anwenden' % len(ev))
alarme = []
for rid, sev, f in REGELN:
    for t in f(ev): alarme.append((rid, sev, t))
for a in alarme: print('  %s %-8s %s' % a)
print('\n## 2. Zusammenfassung')
from collections import Counter
c = Counter(s for _, s, _ in alarme); print('  Alarme: %d (hoch %d, mittel %d, niedrig %d)' % (len(alarme), c['hoch'], c['mittel'], c['niedrig']))
print('\n## 3. Fehlalarme prüfen: einzelne Tippfehler lösen keinen Alarm aus (2 Fehlschläge von anna und ben)')
print('  Alarme für anna/ben: %d' % sum(1 for _, _, t in alarme if 'anna' in t or 'ben' in t))
print('\n## 4. Abschlussprojekt (Aufgabenliste)')
for z in ['Eigenen Beispielbestand mit mindestens 100 Ereignissen erzeugen', 'Abonnement-XML für zwei Kanäle schreiben und prüfen (Modul 4)', 'Filter und Mengenabschätzung (Modul 5)', 'Aufbewahrungsfrist und Prüfsummenliste (Modul 6)', 'zwei eigene Regeln ergänzen und Fehlalarme prüfen', 'Bericht mit offenen Punkten (was wurde nicht in Windows geprüft?)']: print('  -', z)
PY
