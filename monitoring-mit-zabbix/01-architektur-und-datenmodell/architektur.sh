#!/usr/bin/env bash
# Modul 1: Bausteine von Zabbix und Datenmodell (echter Zabbix-Server 7.0.32, Agent, Frontend/API, PostgreSQL).
. "$(dirname "$0")/../lab.sh"
lab_up
step "1. Versionen der Bausteine"
echo "Server: $($ZBX/sbin/zabbix_server -V | head -1)"
echo "Agent:  $($ZBX/sbin/zabbix_agentd -V | head -1)"
echo "API:    $(api0 apiinfo.version)"
echo "Datenbank: $(sql 'show server_version' | cut -d' ' -f1 | cut -d. -f1) (PostgreSQL, Hauptversion)"
step "2. Prozesse des Servers (Anzahl je Art); die Pollerzahl steht in der Konfiguration"
waitfor "ps -eo args | grep -q '^/opt/zbx/inst/sbin/zabbix_server: housekeeper'"; sleep 2
ps -eo args | grep "^/opt/zbx/inst/sbin/zabbix_server: " | sed -E 's#^/opt/zbx/inst/sbin/zabbix_server: ##; s/ #[0-9]+ .*//; s/ *\[.*//; s/ *$//' | sort | uniq -c | sort -k2 | awk '{printf "%3d  %s", $1, $2; for(i=3;i<=NF;i++) printf " %s",$i; print ""}' | head -30
grep -E "^Start" $W/server.conf | tr '\n' ' '; echo
step "3. Passive Prüfung: der Server fragt den Agenten (zabbix_get ahmt das nach)"
for k in agent.ping agent.hostname agent.version; do printf '%-16s -> ' $k; $ZBX/bin/zabbix_get -s 127.0.0.1 -p $AGP -k $k; done
printf 'unbekannter Schlüssel -> '; $ZBX/bin/zabbix_get -s 127.0.0.1 -p $AGP -k kein.schluessel
step "4. Aktive Prüfung: der Agent fragt den Server; unbekannter Host wird abgelehnt (Protokoll des Servers)"
sleep 3; grep -o 'host \[lin01\] not found' $W/server.log | sort -u
step "5. Datenmodell: Tabellen und Inhalt der frisch eingespielten Datenbank"
echo "Tabellen im Schema public: $(sql "select count(*) from information_schema.tables where table_schema='public'")"
echo "Zeilen in hosts nach Art (nur echte Einträge; status 0 = überwacht, 1 = nicht überwacht, 3 = Vorlage):"
sql "select status, count(*) from hosts where flags=0 group by status order by status" | sed 's/^/  status /; s/\t/: /'
for t in hstgrp items triggers actions media_type users dashboard; do printf '  %-11s %s\n' $t "$(sql "select count(*) from $t")"; done
echo "Tabellen für Messwerte (leer, solange keine Textwerte, Protokolle und Ereignisse anfallen):"
for t in history_text history_log trends trends_uint; do printf '  %-13s %s\n' $t "$(sql "select count(*) from $t")"; done
step "6. Wichtige Objekte über die API: Gruppen, Vorlagen, Benutzer"
echo "Host-Gruppen: $(api hostgroup.get '{"output":["name"],"sortfield":"name"}' | jq -r 'map(.name)|join("; ")' | cut -c1-200)"
echo "Vorlagen gesamt: $(api template.get '{"countOutput":true}' | tr -d '"')"
echo "Vorlage gefunden: $(api template.get '{"output":["host"],"filter":{"host":"Linux by Zabbix agent"}}' | jq -r '.[0].host')"
echo "Benutzer: $(api user.get '{"output":["username"],"sortfield":"username"}' | jq -r 'map(.username)|join(", ")')"
