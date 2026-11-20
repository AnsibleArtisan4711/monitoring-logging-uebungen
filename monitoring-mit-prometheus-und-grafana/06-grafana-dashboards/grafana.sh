#!/usr/bin/env bash
# Modul 6: Grafana-Dashboards. Grafana selbst läuft hier NICHT (nicht installierbar, Quelle gesperrt).
# Echt geprüft: Bereitstellungsdateien (YAML), Dashboard-JSON (jq) und die PromQL-Abfragen der Panels gegen das echte Prometheus.
. "$(dirname "$0")/../lab.sh"
lab_up; mk_data
cat > "$W/p.yml" <<'YML'
global: {scrape_interval: 15s}
scrape_configs: []
YML
start_prom "$W/p.yml"
mkdir -p "$W/provisioning/datasources" "$W/provisioning/dashboards"
step "1. Provisioning: Datenquelle und Dashboard-Ordner als Dateien (Grafana liest sie beim Start)"
cat > "$W/provisioning/datasources/prometheus.yml" <<'YML'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    uid: prom-lab
    access: proxy
    url: http://127.0.0.1:9090
    isDefault: true
YML
cat > "$W/provisioning/dashboards/dashboards.yml" <<'YML'
apiVersion: 1
providers:
  - name: uebung
    folder: Uebung
    type: file
    options: {path: /var/lib/grafana/dashboards}
YML
python3 -c "
import yaml,sys
for f in ['datasources/prometheus.yml','dashboards/dashboards.yml']:
    d=yaml.safe_load(open('$W/provisioning/'+f)); print(f,'-> gültiges YAML, Schlüssel:',sorted(d))"
step "2. Dashboard als JSON mit Variable \$instance und drei Panels"
cat > "$W/server.json" <<'JSON'
{
  "uid": "server-uebersicht", "title": "Server-Übersicht", "schemaVersion": 39, "refresh": "30s",
  "time": {"from": "now-2h", "to": "now"},
  "templating": {"list": [{"name": "instance", "type": "query", "datasource": {"uid": "prom-lab"},
    "query": "label_values(node_memory_MemTotal_bytes, instance)", "includeAll": false}]},
  "panels": [
    {"id": 1, "type": "timeseries", "title": "CPU-Auslastung in %", "datasource": {"uid": "prom-lab"},
     "targets": [{"refId": "A", "expr": "100 * (1 - avg(rate(node_cpu_seconds_total{mode=\"idle\",instance=\"$instance\"}[$__rate_interval])))"}]},
    {"id": 2, "type": "gauge", "title": "Speicher belegt in %", "datasource": {"uid": "prom-lab"},
     "targets": [{"refId": "A", "expr": "100 * (1 - node_memory_MemAvailable_bytes{instance=\"$instance\"} / node_memory_MemTotal_bytes{instance=\"$instance\"})"}],
     "fieldConfig": {"defaults": {"unit": "percent", "min": 0, "max": 100,
       "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}, {"color": "orange", "value": 70}, {"color": "red", "value": 90}]}}}},
    {"id": 3, "type": "stat", "title": "Freier Platz auf /", "datasource": {"uid": "prom-lab"},
     "targets": [{"refId": "A", "expr": "node_filesystem_avail_bytes{mountpoint=\"/\",instance=\"$instance\"}"}],
     "fieldConfig": {"defaults": {"unit": "bytes"}}}
  ]
}
JSON
jq -e . "$W/server.json" >/dev/null && echo "server.json: gültiges JSON"
echo "Panels:"; jq -r '.panels[]|"  \(.id) \(.type)\t\(.title)"' "$W/server.json"
echo "Variable: $(jq -r '.templating.list[0]|"\(.name) = \(.query)"' "$W/server.json")"
step "3. Variablenabfrage und Panel-Abfragen gegen das echte Prometheus (Grafana ersetzt \$instance und \$__rate_interval)"
echo "Werte der Variable \$instance (label_values entspricht dieser API-Abfrage):"
curl -s -G "http://127.0.0.1:$PROM/api/v1/series" --data-urlencode 'match[]=node_memory_MemTotal_bytes' --data-urlencode "start=$T0" --data-urlencode "end=$TEVAL" | jq -r '.data[].instance' | sort -u | sed 's/^/  /'
INST="srv01:9100"
jq -r '.panels[]|"\(.id)\t\(.title)\t\(.targets[0].expr)"' "$W/server.json" | while IFS=$'\t' read -r id titel expr; do
  e=${expr//\$instance/$INST}; e=${e//\$__rate_interval/5m}
  echo "Panel $id ($titel) mit instance=$INST:"; echo "  $e"
  q "$e" | sed 's/^/  Wert: /'
done
step "4. Anderer Wert der Variable: srv02 (Platte füllt sich, CPU steigt)"
INST="srv02:9100"
jq -r '.panels[]|"\(.id)\t\(.title)\t\(.targets[0].expr)"' "$W/server.json" | while IFS=$'\t' read -r id titel expr; do
  e=${expr//\$instance/$INST}; e=${e//\$__rate_interval/5m}
  printf 'Panel %s (%s): ' "$id" "$titel"; q "$e" | cut -f2
done
step "5. Fehlerbild: Variable falsch geschrieben, Panel bleibt leer (\"No data\")"
printf 'instance="srv99:9100": '; r=$(q 'node_memory_MemTotal_bytes{instance="srv99:9100"}'); [ -z "$r" ] && echo "leere Antwort (keine Reihe)" || echo "$r"
step "6. Schwellwerte des Gauge-Panels aus dem JSON gelesen"
jq -r '.panels[1].fieldConfig.defaults.thresholds.steps[]|"ab \(.value // "-∞"): \(.color)"' "$W/server.json"
