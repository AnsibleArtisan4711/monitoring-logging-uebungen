#!/usr/bin/env bash
# Modul 3: PromQL gegen die erfundene Messreihe (echter Prometheus; die Werte sind berechnet, nicht gemessen). Auswertezeitpunkt fest: 2026-10-26 14:00 UTC (T0+7200 s).
. "$(dirname "$0")/../lab.sh"
lab_up; mk_data
printf 'global: {scrape_interval: 15s}\nscrape_configs: []\n' > "$W/p.yml"; start_prom "$W/p.yml"
show() { echo "\$ $1"; q "$1"; }
step "1. Instant Vector und Label-Filter"
show 'up'
show 'up{job="node"}'
show 'up{instance=~"srv.*"} == 0'
step "2. Zähler: rate() über 5 Minuten, Summen nach Labels"
show 'rate(node_cpu_seconds_total{mode="idle"}[5m])'
show 'sum by (instance) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))'
step "3. CPU-Auslastung in Prozent und Speicher belegt in Prozent"
show '100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))'
show '100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)'
step "4. Plattenplatz: Prognose mit predict_linear (Stunden bis voll)"
show '100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})'
show 'predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1h], 4*3600) < 0'
show 'node_filesystem_avail_bytes{mountpoint="/"} / -deriv(node_filesystem_avail_bytes{mountpoint="/"}[1h]) / 3600'
step "5. Anwendung: Fehlerquote und 95. Perzentil der Antwortzeit (Histogramm)"
show 'sum by (code) (rate(http_requests_total[5m]))'
show 'sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'
show 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))'
show 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m] offset 1h)))'
step "6. Auswahl und Vergleich"
show 'topk(1, 100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))))'
show 'count(up == 0)'
show 'avg_over_time(node_memory_MemAvailable_bytes{instance="srv01:9100"}[30m]) / 1024^3'
show 'absent(up{job="windows",instance="win02:9182"})'
step "7. Bereichsabfrage: wie viele Messpunkte liefert ein Zeitraum von 10 Minuten bei Schritt 60 s?"
curl -sG "http://127.0.0.1:$PROM/api/v1/query_range" --data-urlencode 'query=up{instance="srv01:9100"}' --data-urlencode "start=$((TEVAL-600))" --data-urlencode "end=$TEVAL" --data-urlencode 'step=60' | jq -r '.data.result[0].values|length|"Punkte: \(.)"'
