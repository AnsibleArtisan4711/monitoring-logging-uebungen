#!/usr/bin/env bash
# Modul 7: Aufbewahrung, Speicherbedarf, Recording Rules, Schnappschuss (echtes Prometheus, erfundene Messreihe).
. "$(dirname "$0")/../lab.sh"
lab_up; mk_data >/dev/null
step "1. Blöcke der Zeitreihendatenbank (promtool tsdb list)"
promtool tsdb list "$W/data" | sed -E 's/^[0-9A-Z]{26}/<ULID>/; s/ {2,}/  /g' 
step "2. Analyse: Reihen, Samples, größte Metriken nach Reihenzahl (promtool tsdb analyze)"
promtool tsdb analyze "$W/data" 2>&1 | sed -n '/^Block ID/,/^Highest cardinality metric names/p' | sed 's/^Block ID: .*/Block ID: …/' | sed '/^Postings entries/q'
promtool tsdb analyze "$W/data" 2>&1 | sed -n '/^Highest cardinality metric names/,+5p'
step "3. Recording Rule: teure Abfrage vorberechnen"
cat > "$W/regeln.yml" <<'YML'
groups:
  - name: vorberechnet
    interval: 1m
    rules:
      - record: instance:cpu_nutzung:rate5m
        expr: 100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))
YML
promtool check rules "$W/regeln.yml" | tail -2
cat > "$W/regeln_test.yml" <<'YML'
rule_files: [regeln.yml]
evaluation_interval: 1m
tests:
  - interval: 15s
    input_series:
      - series: 'node_cpu_seconds_total{instance="a",mode="idle",cpu="0"}'
        values: '0+7.5x40'        # 0,5 s Leerlauf pro Sekunde = 50 % Auslastung
      - series: 'node_cpu_seconds_total{instance="a",mode="user",cpu="0"}'
        values: '0+7.5x40'
    promql_expr_test:
      - expr: instance:cpu_nutzung:rate5m
        eval_time: 9m
        exp_samples:
          - labels: 'instance:cpu_nutzung:rate5m{instance="a"}'
            value: 50
YML
( cd "$W" && promtool test rules regeln_test.yml )
step "4. Aufbewahrung konfigurieren: Zeit und Größe (Startoptionen), Wirkung im laufenden Prometheus"
cat > "$W/p.yml" <<'YML'
global: {scrape_interval: 15s}
scrape_configs: []
YML
nohup prometheus --config.file="$W/p.yml" --storage.tsdb.path="$W/data" --storage.tsdb.retention.time=30d --storage.tsdb.retention.size=1GB --web.enable-admin-api --web.listen-address=127.0.0.1:$PROM >"$W/prom.log" 2>&1 &
waitfor "http://127.0.0.1:$PROM/-/ready"
curl -s "http://127.0.0.1:$PROM/api/v1/status/flags" | jq -r '.data|to_entries[]|select(.key|test("retention"))|"\(.key) = \(.value)"' | sort
echo "Prometheus löscht ganze Blöcke, sobald ihr Ende älter als die Aufbewahrungszeit ist oder die Gesamtgröße die Grenze überschreitet."
step "5. Speicherbedarf abschätzen"
curl -s "http://127.0.0.1:$PROM/api/v1/status/tsdb" | jq -r '.data.headStats|"Reihen im Kopfblock: \(.numSeries)"'
python3 - <<'PY'
reihen=1500; intervall=15; tage=15; bytes_pro_sample=2
samples=reihen*(86400//intervall)*tage
print(f"Beispielrechnung: {reihen} Reihen, alle {intervall} s, {tage} Tage, ~{bytes_pro_sample} Byte/Sample")
print(f"  Samples: {samples:,}".replace(",", "."))
print(f"  Speicher: {samples*bytes_pro_sample/1e9:.2f} GB (Faustwert, Kompression und Index nicht enthalten)")
PY
du -sk "$W/data" | awk '{ if ($1 < 2048) print "Tatsächliche Größe der erfundenen Daten (29 Reihen, 2 Stunden): unter 2 MiB"; else print "Größe: über 2 MiB" }'
step "6. Schnappschuss über die Admin-API"
curl -s -X POST "http://127.0.0.1:$PROM/api/v1/admin/tsdb/snapshot" | jq -r '.status'
ls "$W/data/snapshots" | wc -l | awk '{print "Schnappschüsse: "$1}'
S=$(ls "$W/data/snapshots" | head -1)
promtool tsdb list "$W/data/snapshots/$S" | awk 'NR>1{n++} END{print "Blöcke im Schnappschuss: " n}'
step "7. Reihen löschen (Admin-API) und Platz freigeben"
n0=$(curl -s -G "http://127.0.0.1:$PROM/api/v1/series" --data-urlencode 'match[]=http_requests_total' --data-urlencode "start=$T0" --data-urlencode "end=$TEVAL" | jq '.data|length')
curl -s -o /dev/null -w "DELETE HTTP %{http_code}\n" -X POST -G "http://127.0.0.1:$PROM/api/v1/admin/tsdb/delete_series" --data-urlencode 'match[]=http_requests_total'
n1=$(curl -s -G "http://127.0.0.1:$PROM/api/v1/series" --data-urlencode 'match[]=http_requests_total' --data-urlencode "start=$T0" --data-urlencode "end=$TEVAL" | jq '.data|length')
echo "Reihen http_requests_total vorher: $n0, nachher: $n1"
curl -s -o /dev/null -w "clean_tombstones HTTP %{http_code}\n" -X POST "http://127.0.0.1:$PROM/api/v1/admin/tsdb/clean_tombstones"
