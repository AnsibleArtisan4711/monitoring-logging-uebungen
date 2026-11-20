#!/usr/bin/env bash
# Modul 4: Exporter. Echter node_exporter mit Textfile-Collector, eigener Mini-Exporter (Python), windows_exporter nur als Text (NICHT ausgeführt).
. "$(dirname "$0")/../lab.sh"
lab_up; mkdir -p "$W/textfile"; EXP=19101
nohup prometheus-node-exporter --web.listen-address=127.0.0.1:$NODE --collector.disable-defaults --collector.textfile --collector.textfile.directory="$W/textfile" >"$W/node.log" 2>&1 &
nohup python3 "$HERE/exporter.py" $EXP >"$W/exp.log" 2>&1 &
waitfor "http://127.0.0.1:$NODE/metrics"; waitfor "http://127.0.0.1:$EXP/metrics"
step "1. Textfile-Collector: ein Sicherungsskript schreibt eine .prom-Datei (erst unter anderem Namen, dann umbenennen)"
cat > "$W/sicherung.sh" <<'SH'
#!/usr/bin/env bash
d=$1; t=$(mktemp "$d/.sicherung.XXXX"); cat > "$t" <<M
# HELP sicherung_letzter_erfolg_zeitstempel_sekunden Zeitpunkt der letzten erfolgreichen Sicherung (Unix-Zeit).
# TYPE sicherung_letzter_erfolg_zeitstempel_sekunden gauge
sicherung_letzter_erfolg_zeitstempel_sekunden{job="dateien"} 1793000000
# HELP sicherung_dauer_sekunden Dauer der letzten Sicherung.
# TYPE sicherung_dauer_sekunden gauge
sicherung_dauer_sekunden{job="dateien"} 312
M
mv "$t" "$d/sicherung.prom"
SH
bash "$W/sicherung.sh" "$W/textfile"; ls "$W/textfile"
echo "\$ promtool check metrics < sicherung.prom"; promtool check metrics < "$W/textfile/sicherung.prom"; echo "Rückgabecode $?"
step "2. Der Exporter liefert die Datei aus (Auszug von /metrics)"
curl -s "http://127.0.0.1:$NODE/metrics" | grep -E '^sicherung_|^node_textfile_scrape_error'
step "3. Eigener Exporter: Textformat prüfen"
curl -s "http://127.0.0.1:$EXP/metrics" > "$W/exp.txt"; sed -E "s/^(uebung_abrufe_total) [0-9]+/\1 <Zahl der Abrufe, steigt>/" "$W/exp.txt"
echo "\$ promtool check metrics"; promtool check metrics < "$W/exp.txt"; echo "Rückgabecode $?"
step "4. Prometheus sammelt beide Ziele; Abfrage des Alters der letzten Sicherung (Stand: Zeitstempel in der Datei ist fest, das Alter wächst)"
cat > "$W/p.yml" <<YML
global: {scrape_interval: 2s}
scrape_configs:
  - job_name: node
    static_configs: [{targets: ['127.0.0.1:$NODE']}]
  - job_name: eigener
    static_configs: [{targets: ['127.0.0.1:$EXP']}]
YML
promtool check config "$W/p.yml" | grep -E "SUCCESS|FAILED"
start_prom "$W/p.yml"; wait_targets; sleep 5
qn 'up'
qn 'uebung_warteschlange_laenge'
echo "Alter der Sicherung größer als 1 Tag (86400 s)? Ergebnis (1 = ja):"; qn '(time() - sicherung_letzter_erfolg_zeitstempel_sekunden > bool 86400)'
echo "Zähler des eigenen Exporters wächst; rate() über 4 s größer als 0 (1 = ja):"; qn 'rate(uebung_abrufe_total[4s]) > bool 0'
step "5. windows_exporter (NICHT ausgeführt): so würde das Ziel in der Konfiguration stehen; die Prüfung betrifft nur die Syntax der Prometheus-Datei"
cat > "$W/win.yml" <<'YML'
scrape_configs:
  - job_name: windows
    static_configs:
      - targets: ['win01:9182']      # Standardport laut Fachwissen, nicht bestätigt
        labels: {rolle: dateiserver}
YML
cat "$W/win.yml"; promtool check config "$W/win.yml" | grep -E "SUCCESS|FAILED"
echo "Die Sammler (collectors) von windows_exporter, zum Beispiel cpu, logical_disk, memory, net, os, service, werden in dessen Aufruf oder Konfigurationsdatei ausgewählt; Namen und Optionen wurden NICHT geprüft."
