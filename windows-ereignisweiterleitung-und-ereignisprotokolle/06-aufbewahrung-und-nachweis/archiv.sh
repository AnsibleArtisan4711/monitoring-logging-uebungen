#!/usr/bin/env bash
# Modul 6: Aufbewahrung und Archivierung (Modell mit Dateien): Tagesdateien, Aufbewahrungsfrist, Prüfsummenliste gegen nachträgliche Änderung.
. "$(dirname "$0")/../lab.sh"
lab_up; A="$W/archiv"; mkdir -p "$A"
step "1. Tagesarchive anlegen: 10 Tage mit je einer Zeile je Ereignis (erfundene Mengen)"
for t in $(seq 1 10); do d=$(printf '2026-11-%02d' $t); for i in $(seq 1 $((t * 3))); do echo "$d eintrag$i"; done > "$A/$d.log"; done
ls "$A" | head -3; echo "..."; ls "$A" | tail -1; echo "Dateien: $(ls "$A" | wc -l), Zeilen gesamt: $(cat "$A"/*.log | wc -l)"
step "2. Aufbewahrungsfrist 7 Tage (Stichtag 2026-11-10): Trockenlauf zeigt, was gelöscht würde"
stichtag=2026-11-10; frist=7
alt() { for f in "$A"/*.log; do d=$(basename "$f" .log); [ $(( ($(date -d $stichtag +%s) - $(date -d $d +%s)) / 86400 )) -gt $frist ] && echo "$f"; done; }
alt | xargs -r -n1 basename
step "3. Prüfsummenliste anlegen, bevor gelöscht wird (Nachweis der Vollständigkeit)"
( cd "$A" && sha256sum *.log > ../manifest.sha256 ); wc -l < "$W/manifest.sha256" | sed 's/^/Einträge in der Liste: /'
step "4. Löschen der alten Dateien und Prüfung der Restdateien"
alt | xargs -r rm; ls "$A" | wc -l | sed 's/^/Verbleibende Dateien: /'
( cd "$A" && sha256sum -c ../manifest.sha256 2>&1 | grep -c ': OK' | sed 's/^/Prüfsumme OK: /' ; sha256sum -c ../manifest.sha256 2>&1 | grep -c 'FAILED open' | sed 's/^/Datei fehlt (gelöscht nach Frist): /' )
step "5. Nachträgliche Änderung einer Datei wird bemerkt"
echo "gefälscht" >> "$A/2026-11-09.log"
( cd "$A" && sha256sum -c ../manifest.sha256 2>&1 | grep 'FAILED$' )
step "6. Größenbegrenzung im Modell: Rotation bei 40 Zeilen (statt Überschreiben des ältesten Eintrags)"
rm -f "$W/aktiv.log"* ; for i in $(seq 1 100); do echo "e$i" >> "$W/aktiv.log"; [ $(wc -l < "$W/aktiv.log") -ge 40 ] && mv "$W/aktiv.log" "$W/aktiv.log.$(ls "$W"/aktiv.log.* 2>/dev/null | wc -l)"; done
ls "$W" | grep aktiv; echo "Zeilen in aktiv.log: $(wc -l < "$W/aktiv.log")"
step "7. Hinweis"
echo "Windows-Protokolle haben eine eigene Größenbegrenzung und Aufbewahrungsmethode je Protokoll; das Modell ersetzt keine Einstellung des Betriebssystems. Rechtliche Fristen (zum Beispiel Datenschutz, Aufbewahrungspflichten) wurden nicht geprüft."
