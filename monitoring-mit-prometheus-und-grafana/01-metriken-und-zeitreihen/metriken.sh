#!/usr/bin/env bash
# Modul 1: Metriken und Zeitreihen. Echter node_exporter (Ubuntu-Paket), nur wenige Collector, nur Loopback.
. "$(dirname "$0")/../lab.sh"
lab_up; mkdir -p "$W/textfile"
nohup prometheus-node-exporter --web.listen-address=127.0.0.1:$NODE --collector.disable-defaults --collector.cpu --collector.meminfo --collector.loadavg --collector.textfile --collector.textfile.directory="$W/textfile" >"$W/node.log" 2>&1 &
waitfor "http://127.0.0.1:$NODE/metrics"
step "1. Eine Metrik im Textformat: HELP, TYPE und Messwerte (Auszug)"
curl -s "http://127.0.0.1:$NODE/metrics" | grep -E '^(# (HELP|TYPE) node_memory_MemTotal_bytes|node_memory_MemTotal_bytes|# (HELP|TYPE) node_cpu_seconds_total|node_cpu_seconds_total\{cpu="0",mode="(idle|user)"\})' | sed -E 's/^(node_cpu_seconds_total\{[^}]*\}) .*/\1 <WERT>/'
step "2. Metrikarten im gesamten Bestand (Anzahl je TYPE)"
curl -s "http://127.0.0.1:$NODE/metrics" | awk '/^# TYPE/{t[$4]++} END{for(k in t) print "  " k, t[k]}' | sort
step "3. Zähler (counter) wächst, Messwert (gauge) schwankt: zweimal lesen, 3 Sekunden Abstand"
read_pair() { curl -s "http://127.0.0.1:$NODE/metrics" | awk '/^node_cpu_seconds_total\{cpu="0",mode="idle"\}/{print $2}'; }
a=$(read_pair); sleep 3; b=$(read_pair)
python3 - "$a" "$b" <<'PY'
import sys
a, b = float(sys.argv[1]), float(sys.argv[2])
print('Zähler idle (cpu 0): erster Wert größer 0:', a > 0, '| zweiter Wert nicht kleiner:', b >= a)
print('Anstieg in 3 s zwischen 0 und 3 Sekunden (ein Kern, höchstens 3 s Leerlauf):', 0 <= b - a <= 3.2)
print('Zähler zeigen erst durch rate() eine Geschwindigkeit, siehe Modul 3.')
PY
step "4. Zeitreihen zählen: jede Kombination aus Namen und Labelwerten ist eine Reihe"
n=$(curl -s "http://127.0.0.1:$NODE/metrics" | grep -c '^node_cpu_seconds_total{')
cpus=$(nproc); echo "node_cpu_seconds_total: $n Reihen = $cpus Kerne x $((n / cpus)) Modi"
python3 -c "print('Rechenbeispiel: 50 Hosts x 4 Kerne x 8 Modi =', 50*4*8, 'Reihen allein für diese eine Metrik')"
step "5. Der Prüfer promtool check metrics: Ausgabe des Exporters (Auszug) und eine absichtlich schlechte Metrik"
out=$(curl -s "http://127.0.0.1:$NODE/metrics" | promtool check metrics 2>&1); rc=$?
echo "$out" | head -3; echo "... Beanstandungen insgesamt: $(echo "$out" | wc -l), Rückgabecode $rc (0 = keine Beanstandung)"
echo "Beispiel: auch der echte Exporter verletzt die Namensregel (camelCase) in Namen, die aus /proc/meminfo stammen."
printf '# TYPE anfragen counter\nanfragen 5\n# TYPE speicherGB gauge\nspeicherGB 3\n' | promtool check metrics; echo "Rückgabecode $?"
