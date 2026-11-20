#!/usr/bin/env bash
# Modul 8: Betrieb, Konfiguration neu laden, Zugriffsschutz, Sicherung/Wiederherstellung, Abschlussprojekt (echte Programme, Loopback).
. "$(dirname "$0")/../lab.sh"
lab_up; mk_data >/dev/null
nohup prometheus-node-exporter --web.listen-address=127.0.0.1:$NODE --collector.disable-defaults --collector.loadavg >"$W/node.log" 2>&1 &
waitfor "http://127.0.0.1:$NODE/metrics"
cat > "$W/p.yml" <<YML
global: {scrape_interval: 5s}
scrape_configs:
  - job_name: node
    static_configs: [{targets: ['127.0.0.1:$NODE'], labels: {rolle: lab}}]
YML
nohup prometheus --config.file="$W/p.yml" --storage.tsdb.path="$W/data" --web.enable-lifecycle --web.enable-admin-api --web.listen-address=127.0.0.1:$PROM >"$W/prom.log" 2>&1 &
waitfor "http://127.0.0.1:$PROM/-/ready"; wait_targets
step "1. Gesundheit prüfen: /-/healthy, /-/ready, Version"
for p in healthy ready; do printf '/-/%s -> ' $p; curl -s "http://127.0.0.1:$PROM/-/$p"; done
curl -s "http://127.0.0.1:$PROM/api/v1/status/buildinfo" | jq -r '.data|"Version \(.version), Go \(.goVersion)"' | sed -E 's/Version [0-9.]+(\+ds[0-9]*)?/Version <Paketstand>/; s/Go go[0-9.]+/Go <Version>/'
step "2. Konfiguration ändern und im Betrieb neu laden (ohne Neustart)"
echo "Ziele vorher: $(curl -s http://127.0.0.1:$PROM/api/v1/targets | jq '.data.activeTargets|length')"
cat >> "$W/p.yml" <<YML
  - job_name: prometheus
    static_configs: [{targets: ['127.0.0.1:$PROM']}]
YML
promtool check config "$W/p.yml" | grep -E 'SUCCESS|FAILED'
curl -s -o /dev/null -w "POST /-/reload HTTP %{http_code}\n" -X POST "http://127.0.0.1:$PROM/-/reload"; sleep 7
echo "Ziele nachher: $(curl -s http://127.0.0.1:$PROM/api/v1/targets | jq '.data.activeTargets|length')"
step "3. Fehlerhafte Konfiguration: Reload wird abgelehnt, alte Konfiguration bleibt"
cp "$W/p.yml" "$W/p.ok"; printf '  - job_name: kaputt\n    static_configs: [{targets: [x]\n' >> "$W/p.yml"
promtool check config "$W/p.yml" 2>&1 | grep -E 'SUCCESS|FAILED' ; echo "promtool-Rückgabecode: ${PIPESTATUS[0]}"
curl -s -o /dev/null -w "POST /-/reload HTTP %{http_code}\n" -X POST "http://127.0.0.1:$PROM/-/reload"
echo "Ziele weiterhin: $(curl -s http://127.0.0.1:$PROM/api/v1/targets | jq '.data.activeTargets|length')"
cp "$W/p.ok" "$W/p.yml"; curl -s -o /dev/null -X POST "http://127.0.0.1:$PROM/-/reload"
step "4. Zugriffsschutz: web.yml mit Basic Auth (bcrypt-Hash) und Test"
HASH=$(python3 -c "import bcrypt;print(bcrypt.hashpw(b'uebung-passwort',bcrypt.gensalt(10)).decode())")
cat > "$W/web.yml" <<YML
basic_auth_users:
  admin: '$HASH'
YML
promtool check web-config "$W/web.yml"
nohup prometheus --config.file="$W/p.yml" --storage.tsdb.path="$W/data2" --web.config.file="$W/web.yml" --web.listen-address=127.0.0.1:19091 >"$W/prom2.log" 2>&1 &
for _ in $(seq 1 60); do curl -sf -u admin:uebung-passwort http://127.0.0.1:19091/-/healthy >/dev/null && break; sleep 0.5; done
printf 'ohne Anmeldung: HTTP '; curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:19091/api/v1/status/buildinfo
printf 'falsches Passwort: HTTP '; curl -s -o /dev/null -w '%{http_code}\n' -u admin:falsch http://127.0.0.1:19091/api/v1/status/buildinfo
printf 'richtiges Passwort: HTTP '; curl -s -o /dev/null -w '%{http_code}\n' -u admin:uebung-passwort http://127.0.0.1:19091/api/v1/status/buildinfo
pkill -f "web.listen-address=127.0.0.1:19091"
step "5. Sicherung: Schnappschuss kopieren; Wiederherstellung: neues Prometheus auf der Kopie"
curl -s -X POST "http://127.0.0.1:$PROM/api/v1/admin/tsdb/snapshot" | jq -r .status
S=$(ls "$W/data/snapshots" | head -1); mkdir -p "$W/sicherung" && cp -r "$W/data/snapshots/$S" "$W/sicherung/wiederherstellung"
tar czf "$W/sicherung.tar.gz" -C "$W/sicherung" . && tar tzf "$W/sicherung.tar.gz" | grep -c chunks | awk '{print "Archiv enthält Blöcke mit Chunks: ja ("$1" Einträge)"}'
nohup prometheus --config.file="$W/p.ok" --storage.tsdb.path="$W/sicherung/wiederherstellung" --storage.tsdb.retention.time=3650d --web.listen-address=127.0.0.1:19092 >"$W/prom3.log" 2>&1 &
waitfor "http://127.0.0.1:19092/-/ready"
printf 'Wiederhergestellt: Reihen up aus der erfundenen Messreihe (Soll 3): '
curl -s -G http://127.0.0.1:19092/api/v1/query --data-urlencode 'query=count(up)' --data-urlencode "time=$TEVAL" | jq -r '.data.result[0].value[1]'
step "6. Abschlussprojekt - Abnahmeprüfung des Mini-Stacks (je Prüfpunkt OK/FEHLER)"
chk() { if eval "$2" >/dev/null 2>&1; then echo "OK      $1"; else echo "FEHLER  $1"; fi; }
chk "Prometheus bereit"            "curl -sf http://127.0.0.1:$PROM/-/ready"
chk "node_exporter-Ziel up"        "[ \"\$(curl -s -G http://127.0.0.1:$PROM/api/v1/query --data-urlencode 'query=up{job=\"node\"}' | jq -r '.data.result[0].value[1]')\" = 1 ]"
chk "Konfiguration gültig"         "promtool check config $W/p.yml"
chk "Admin-API Schnappschuss"      "ls $W/data/snapshots/*"
chk "Sicherungsarchiv vorhanden"   "[ -s $W/sicherung.tar.gz ]"
chk "Wiederherstellung antwortet"  "curl -sf http://127.0.0.1:19092/-/ready"
chk "Zugriffsschutz konfiguriert"  "promtool check web-config $W/web.yml"
chk "absichtlich falsch: Port 1"   "curl -sf http://127.0.0.1:1/"
pkill -f "web.listen-address=127.0.0.1:19092"
