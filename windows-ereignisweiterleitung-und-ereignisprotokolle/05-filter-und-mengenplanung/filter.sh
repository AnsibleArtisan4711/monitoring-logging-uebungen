#!/usr/bin/env bash
# Modul 5: Was wird weitergeleitet? Filterstrategien und Mengenabschätzung mit erfundenen Beispieldaten (Modellrechnung).
. "$(dirname "$0")/../lab.sh"
lab_up; D="$(dirname "$0")/.."
python3 - "$W/events.xml" "$D" <<'PY'
import sys; sys.path.insert(0, sys.argv[2])
from evlib import *
from collections import Counter
ev = lade(sys.argv[1]); n = len(ev)
sets = {
  'alles weiterleiten': lambda e: True,
  'nur Kanal Security': lambda e: kanal(e) == 'Security',
  'Sicherheitsrelevante IDs (4625, 4740, 4720, 1102, 7045)': lambda e: eid(e) in (4625, 4740, 4720, 1102, 7045),
  'IDs plus erfolgreiche Anmeldungen (4624)': lambda e: eid(e) in (4625, 4740, 4720, 1102, 7045, 4624),
}
print('\n## 1. Filtermengen im Beispielbestand (%d Ereignisse)' % n)
for name, f in sets.items():
    k = sum(1 for e in ev if f(e)); print('  %-58s %3d  (%3d %% des Bestands)' % (name, k, round(100 * k / n)))
print('\n## 2. Hochrechnung (Annahmen, keine Messung): 200 Computer, Beispielbestand = 4 Stunden von drei Computern, 1 KB je Ereignis')
az = 200; pro_tag_je_pc = n / 3 * 6      # drei Computer im Bestand, 4 h -> 24 h = Faktor 6
for name, f in list(sets.items()):
    k = sum(1 for e in ev if f(e)) / 3 * 6
    tag = k * az; print('  %-58s %8.0f Ereignisse/Tag  %6.1f MB/Tag  %5.2f Ereignisse/s' % (name, tag, tag / 1024, tag / 86400))
print('\n## 3. Einordnung (Dokumentation: Faustregel 3000 Ereignisse je Sekunde im Mittel für einen Sammler auf gewöhnlicher Hardware)')
alles = n / 3 * 6 * az / 86400
print('  Hochrechnung "alles": %.2f Ereignisse/s = %.2f %% der Faustregel' % (alles, 100 * alles / 3000))
print('\n## 4. Rauschen erkennen: häufigste IDs, die nicht sicherheitsrelevant sind')
for i, c in Counter(eid(e) for e in ev if eid(e) in (1000, 1001, 1002, 37)).most_common(): print('  ID %5d: %2d Ereignisse' % (i, c))
print('\n## 5. Hinweis')
print('  Die Hochrechnung nimmt gleiche Raten für alle Computer an; echte Raten schwanken stark. Zahlen vor der Planung messen.')
PY
