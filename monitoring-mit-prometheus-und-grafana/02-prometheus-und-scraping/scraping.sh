#!/usr/bin/env bash
# Modul 2: Prometheus konfigurieren und Ziele abfragen (echter Prometheus 2.45, echter node_exporter, nur Loopback).
. "$(dirname "$0")/../lab.sh"
lab_up; mkdir -p "$W/sd"
nohup prometheus-node-exporter --web.listen-address=127.0.0.1:$NODE --collector.disable-defaults --collector.loadavg >"$W/node.log" 2>&1 &
waitfor "http://127.0.0.1:$NODE/metrics"
cat > "$W/prometheus.yml" <<YML
global:
  scrape_interval: 2s            # nur für die Übung; im Betrieb meist 15 s
  external_labels: {labor: p18}
scrape_configs:
  - job_name: prometheus
    static_configs: [{targets: ['127.0.0.1:$PROM']}]
  - job_name: node
    static_configs:
      - targets: ['127.0.0.1:$NODE']
        labels: {rolle: test}
    relabel_configs:
      - target_label: umgebung
        replacement: uebung
  - job_name: datei
    file_sd_configs: [{files: ['$W/sd/*.json'], refresh_interval: 2s}]
YML
echo '[]' > "$W/sd/ziele.json"
step "1. Konfiguration prüfen (promtool check config)"
cmd promtool check config "$W/prometheus.yml"
step "2. Eine fehlerhafte Konfiguration (Einrückung) wird gemeldet"
printf 'scrape_configs:\n- job_name: x\n  static_configs:\n   - targets: ["a:1"]\n  scrape_interval 5s\n' > "$W/kaputt.yml"
cmd promtool check config "$W/kaputt.yml"; echo "rc=$?"
step "3. Prometheus starten, kurz warten, Ziele abfragen (Zustand und Labels)"
start_prom "$W/prometheus.yml"; wait_targets; sleep 1
curl -s "http://127.0.0.1:$PROM/api/v1/targets" | jq -r '.data.activeTargets[]|[.labels.job, .health, (.labels.rolle//"-"), (.labels.umgebung//"-")]|@tsv' | sort
step "4. Die Abfrage up und die Selbstbeschreibung (external_labels erscheinen nur bei Weitergabe, nicht in der Abfrage)"
qn 'up'
step "5. Neues Ziel per Datei (file_sd): node_exporter ein zweites Mal als Ziel unter anderem Namen eintragen, ohne Neustart"
echo "[{\"targets\":[\"localhost:$NODE\"],\"labels\":{\"job\":\"datei-ziel\",\"rolle\":\"zusatz\"}}]" > "$W/sd/ziele.json"; sleep 6
curl -s "http://127.0.0.1:$PROM/api/v1/targets" | jq -r '.data.activeTargets[]|select(.labels.rolle=="zusatz")|[.labels.job,.labels.instance,.health]|@tsv'
step "6. Zeitreihen im Speicher des Kopfblocks (prometheus_tsdb_head_series > 0)"
qn 'prometheus_tsdb_head_series > bool 0'
