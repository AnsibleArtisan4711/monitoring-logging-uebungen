#!/usr/bin/env bash
# Modul 5: Alarmregeln, Regeltests und Alertmanager (echte Programme; Webhook-Empfänger statt E-Mail, nur Loopback).
. "$(dirname "$0")/../lab.sh"
lab_up
cat > "$W/alarme.yml" <<'YML'
groups:
  - name: hosts
    rules:
      - alert: HostDown
        expr: up == 0
        for: 2m
        labels: {severity: critical, team: infra}
        annotations: {summary: "{{ $labels.instance }} ist nicht erreichbar"}
      - alert: DiskWillFillIn4h
        expr: predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1h], 4*3600) < 0
        for: 5m
        labels: {severity: warning, team: infra}
        annotations: {summary: "{{ $labels.instance }}: Platte läuft in 4 Stunden voll"}
      - alert: HighCpu
        expr: 100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 80
        for: 10m
        labels: {severity: warning, team: infra}
YML
step "1. Regeldatei prüfen (promtool check rules)"
cmd promtool check rules "$W/alarme.yml"
step "2. Regeltest mit erfundenen Reihen (promtool test rules): HostDown und Plattenprognose"
cat > "$W/alarme_test.yml" <<'YML'
rule_files: [alarme.yml]
evaluation_interval: 1m
tests:
  - interval: 1m
    input_series:
      - series: 'up{instance="srv02:9100",job="node"}'
        values: '1 1 1 0 0 0 0 0 0 0'
      - series: 'node_filesystem_avail_bytes{instance="srv02:9100",job="node",mountpoint="/"}'
        values: '100000000000-1000000000x40'
    alert_rule_test:
      - eval_time: 4m
        alertname: HostDown
        exp_alerts: []                  # nach 1 Minute ohne Antwort erst "pending", noch nicht "firing"
      - eval_time: 6m
        alertname: HostDown
        exp_alerts:
          - exp_labels: {severity: critical, team: infra, instance: "srv02:9100", job: node}
            exp_annotations: {summary: "srv02:9100 ist nicht erreichbar"}
      - eval_time: 15m
        alertname: DiskWillFillIn4h
        exp_alerts:
          - exp_labels: {severity: warning, team: infra, instance: "srv02:9100", job: node, mountpoint: "/"}
            exp_annotations: {summary: "srv02:9100: Platte läuft in 4 Stunden voll"}
YML
( cd "$W" && cmd promtool test rules alarme_test.yml )
step "3. Derselbe Test mit falscher Erwartung (HostDown schon nach 4 Minuten) schlägt fehl"
cat > "$W/alarme_test_falsch.yml" <<'YML'
rule_files: [alarme.yml]
evaluation_interval: 1m
tests:
  - interval: 1m
    input_series:
      - series: 'up{instance="srv02:9100",job="node"}'
        values: '1 1 1 0 0 0 0 0 0 0'
    alert_rule_test:
      - eval_time: 4m          # falsch: for: 2m ist noch nicht abgelaufen, der Alarm feuert erst später
        alertname: HostDown
        exp_alerts:
          - exp_labels: {severity: critical, team: infra, instance: "srv02:9100", job: node}
YML
( cd "$W" && promtool test rules alarme_test_falsch.yml 2>&1 | sed -n "1,12p"; echo "Rückgabecode ${PIPESTATUS[0]}" )
step "4. Alertmanager-Konfiguration: Routing nach Schweregrad, Hemmung, Webhook"
cat > "$W/am.yml" <<YML
route:
  receiver: standard
  group_by: [alertname]
  group_wait: 1s
  group_interval: 3s
  repeat_interval: 4h
  routes:
    - matchers: ['severity="critical"']
      receiver: bereitschaft
      group_wait: 0s
receivers:
  - name: standard
    webhook_configs: [{url: 'http://127.0.0.1:$HOOK/standard'}]
  - name: bereitschaft
    webhook_configs: [{url: 'http://127.0.0.1:$HOOK/bereitschaft'}]
inhibit_rules:
  - source_matchers: ['severity="critical"']
    target_matchers: ['severity="warning"']
    equal: [instance]
YML
cmd amtool check-config "$W/am.yml"
echo "\$ amtool config routes show"; amtool config routes show --config.file="$W/am.yml" 2>&1 | grep -v "^Warning"
for l in "severity=critical" "severity=warning" "alertname=HighCpu"; do echo "\$ amtool config routes test $l"; amtool config routes test --config.file="$W/am.yml" $l 2>&1 | grep -v "^Warning"; done
step "5. Alertmanager und Webhook starten; Alarme senden (amtool alert add)"
nohup python3 "$HERE/webhook.py" $HOOK "$W/hook.log" >/dev/null 2>&1 &
nohup prometheus-alertmanager --config.file="$W/am.yml" --storage.path="$W/am" --web.listen-address=127.0.0.1:$AM --cluster.listen-address= >"$W/am.log" 2>&1 &
waitfor "http://127.0.0.1:$AM/-/ready"
AMU="--alertmanager.url=http://127.0.0.1:$AM"
amtool $AMU alert add HostDown instance=srv02 severity=critical team=infra
amtool $AMU alert add HighCpu instance=srv01 severity=warning team=infra
amtool $AMU alert add DiskWillFillIn4h instance=srv02 severity=warning team=infra
sleep 5
echo "Benachrichtigungen im Webhook (sortiert):"; sort "$W/hook.log"
step "6. Warnungen derselben Instanz werden durch die kritische Meldung gehemmt (inhibited); aktive Alarme"
J='.[]|"\(.labels.alertname)@\(.labels.instance)  Zustand: \(.status.state)"'
echo "Unterdrückt (inhibited):"; amtool $AMU alert query --inhibited -o json | jq -r "$J" | sort | sed 's/^/  /'
echo "Aktiv (nicht unterdrückt):"; amtool $AMU alert query -o json | jq -r "$J" | sort | sed 's/^/  /'
step "7. Stummschaltung (silence): HostDown für srv01 wird nicht gemeldet"
amtool $AMU silence add alertname=HostDown instance=srv01 --comment="Wartung" --duration=1h --author=uebung >/dev/null
: > "$W/hook.log"
amtool $AMU alert add HostDown instance=srv01 severity=critical team=infra; sleep 3
echo "Webhook-Einträge nach der Stummschaltung: $(wc -l < "$W/hook.log")"
amtool $AMU silence query -o json | jq -r '.[] | "Stummschaltung: \(.matchers|map(.name+"="+.value)|join(",")) Kommentar=\(.comment) Status=\(.status.state)"'
