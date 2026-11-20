#!/usr/bin/env bash
# Gemeinsame Hilfen der Übungsreihe (P18). Echte Programme: Prometheus, Alertmanager, node_exporter (Ubuntu-Pakete). Grafana und windows_exporter laufen NICHT.
# Die Messwerte der Module 3, 5, 6, 7 sind erfunden (gen_data.py) und werden mit promtool in Prometheus eingespielt.
W=/tmp/p18; HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROM=19090; NODE=19100; AM=19093; HOOK=19095
T0=1793000400; TEVAL=$((T0+7200))   # 2026-10-26, Messreihe von T0 bis T0+7200 s (2 Stunden, alle 15 s)
step() { echo; echo "## $*"; }
cmd() { echo "\$ $*"; "$@" 2>&1; return $?; }
waitfor() { for _ in $(seq 1 60); do curl -sf "$1" >/dev/null 2>&1 && return 0; sleep 0.5; done; echo "TIMEOUT $1"; return 1; }
lab_up() { lab_down >/dev/null 2>&1; mkdir -p "$W"; }
lab_down() { pkill -f "prometheus --config.file=$W" 2>/dev/null; pkill -f "prometheus-alertmanager --config.file=$W" 2>/dev/null; pkill -f "prometheus-node-exporter --web.listen-address=127.0.0.1:$NODE" 2>/dev/null; pkill -f "$HERE/webhook.py" 2>/dev/null; sleep 1; rm -rf "$W"; }
trap 'lab_down >/dev/null 2>&1' EXIT
# erfundene Messreihe als Blöcke in $W/data
mk_data() { python3 "$HERE/gen_data.py" "$W/daten.om" && promtool tsdb create-blocks-from openmetrics "$W/daten.om" "$W/data" 2>&1 >/dev/null 2>&1; }
start_prom() { # Argument: Konfigurationsdatei, weitere Optionen
  local cfg=$1; shift
  nohup prometheus --config.file="$cfg" --storage.tsdb.path="$W/data" --storage.tsdb.retention.time=3650d --web.listen-address=127.0.0.1:$PROM "$@" >"$W/prom.log" 2>&1 &
  waitfor "http://127.0.0.1:$PROM/-/ready"; }
# Anfrage zum festen Zeitpunkt TEVAL; Ausgabe: Labels<TAB>Wert, sortiert
q() { curl -sG "http://127.0.0.1:$PROM/api/v1/query" --data-urlencode "query=$1" --data-urlencode "time=${2:-$TEVAL}" | jq -r '.data.result[]|[((.metric|del(.__name__)|to_entries|map("\(.key)=\(.value)")|join(",")) as $l|if $l=="" then "(ohne Labels)" else $l end), (.value[1]|tonumber|(.*1000|round)/1000|tostring)]|@tsv' | sort; }
# Anfrage zum aktuellen Zeitpunkt (für laufende Ziele)
qn() { curl -sG "http://127.0.0.1:$PROM/api/v1/query" --data-urlencode "query=$1" | jq -r '.data.result[]|[((.metric|del(.__name__)|to_entries|map("\(.key)=\(.value)")|join(",")) as $l|if $l=="" then "(ohne Labels)" else $l end), (.value[1]|tonumber|(.*1000|round)/1000|tostring)]|@tsv' | sort; }
# warten, bis Ziele vorhanden sind und keines mehr "unknown" ist
wait_targets() { for _ in $(seq 1 60); do r=$(curl -s "http://127.0.0.1:$PROM/api/v1/targets" | jq '(.data.activeTargets|length) as $t|([.data.activeTargets[]|select(.health=="unknown")]|length) as $u|if $t>0 and $u==0 then 1 else 0 end' 2>/dev/null); [ "$r" = "1" ] && return 0; sleep 0.5; done; }
