#!/usr/bin/env bash
# Modul 1: Aufbau von Ereignissen und Protokollkanälen. Erfundene Ereignisse im Aufbau von Windows-Ereignissen (XML); KEIN Windows im Test.
. "$(dirname "$0")/../lab.sh"
lab_up; D="$(dirname "$0")/.."
step "1. Ein Ereignis im Aufbau (System-Teil und Nutzdaten), ein erfundenes Anmeldeereignis"
xmllint --format --xpath '(//*[local-name()="Event"][*[local-name()="System"]/*[local-name()="EventID"]="4625"])[1]' "$W/events.xml"; echo
step "2. Ereignisse je Kanal und Computer"
python3 - "$W/events.xml" "$D" <<'PY'
import sys; sys.path.insert(0, sys.argv[2])
from evlib import *; from collections import Counter
e = lade(sys.argv[1]); print('Ereignisse gesamt:', len(e))
for k, n in sorted(Counter(map(kanal, e)).items()): print('  %-12s %3d' % (k, n))
for h, n in sorted(Counter(map(host, e)).items()): print('  %-18s %3d' % (h, n))
PY
step "3. Ereignis-IDs im Datenbestand (Anzahl)"
python3 - "$W/events.xml" "$D" <<'PY'
import sys; sys.path.insert(0, sys.argv[2])
from evlib import *; from collections import Counter
for i, n in sorted(Counter(map(eid, lade(sys.argv[1]))).items()): print('  %5d %3d' % (i, n))
PY
step "4. Bedeutung einiger IDs (laut Microsoft-Dokumentation: 4624, 4625, 4634, 4740, 1102 in Suchauszügen gelesen; 4720 und 7045 aus Fachwissen)"
cat <<'T'
4624 erfolgreiche Anmeldung     4625 fehlgeschlagene Anmeldung     4634 Abmeldung
4740 Konto gesperrt             4720 Benutzerkonto erstellt        1102 Überwachungsprotokoll gelöscht
7045 Dienst installiert (System-Protokoll)
T
step "5. Hinweis"
echo "Reale Windows-Ereignisse haben mehr Felder; der Aufbau hier ist vereinfacht und nicht gegen das Ereignisschema geprüft."
