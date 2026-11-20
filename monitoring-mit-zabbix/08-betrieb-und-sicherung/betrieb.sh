#!/usr/bin/env bash
# Modul 8: Betrieb, Selbstüberwachung, Housekeeping, Sicherung und Wiederherstellung, Abschlussprojekt (echter Zabbix 7.0.32 mit PostgreSQL).
. "$(dirname "$0")/../lab.sh"
lab_up
step "1. Selbstüberwachung: interne Items (Typ 5) auf einem Host ohne Schnittstelle"
GID=$(api hostgroup.create '{"name":"Uebung-Intern"}' | jq -r '.groupids[0]')
HID=$(api host.create "{\"host\":\"zbx-intern\",\"groups\":[{\"groupid\":\"$GID\"}]}" | jq -r '.hostids[0]')
mki() { api item.create "{\"hostid\":\"$HID\",\"name\":\"$1\",\"key_\":\"$2\",\"type\":5,\"value_type\":$3,\"delay\":\"$4\"}" | jq -r '.itemids[0]'; }
Q=$(mki "Warteschlange" 'zabbix[queue]' 3 2s); WV=$(mki "Gespeicherte Werte" 'zabbix[wcache,values]' 3 2s)
CF=$(mki "Konfigurationscache frei in %" 'zabbix[rcache,buffer,pfree]' 0 2s); PB=$(mki "Poller ausgelastet in %" 'zabbix[process,poller,avg,busy]' 0 2s)
printf 'zabbix[queue] (Werte im Rückstand) = %s\n' "$(wait_val $Q)"
v=0; for _ in $(seq 1 40); do v=$(hist $WV); [ "${v:-0}" -gt 0 ] 2>/dev/null && break; sleep 0.5; done; echo "zabbix[wcache,values] (gespeicherte Werte seit Start) ist eine Zahl größer 0: $([ "$v" -gt 0 ] 2>/dev/null && echo ja || echo nein)"
v=$(wait_val $CF); echo "zabbix[rcache,buffer,pfree] (freier Konfigurationscache) über 50 %: $(awk -v v="$v" 'BEGIN{print (v>50)?"ja":"nein"}')"
v=$(wait_val $PB); echo "zabbix[process,poller,avg,busy] unter 100 %: $(awk -v v="$v" 'BEGIN{print (v<100)?"ja":"nein"}')"
step "2. Erwartete Werte je Sekunde (NVPS) aus den Intervallen der Items berechnen"
for d in 1m 5s 2s; do api item.create "{\"hostid\":\"$HID\",\"name\":\"NVPS-Beispiel $d\",\"key_\":\"zabbix[queue,$d]\",\"type\":5,\"value_type\":3,\"delay\":\"$d\"}" >/dev/null 2>&1; done
api item.get "{\"hostids\":\"$HID\",\"output\":[\"delay\"],\"search\":{\"name\":\"NVPS-Beispiel\"}}" | jq -r 'map(.delay)|sort|join(", ")|"Intervalle der Beispiel-Items: \(.)"'
api item.get "{\"hostids\":\"$HID\",\"output\":[\"delay\"],\"search\":{\"name\":\"NVPS-Beispiel\"}}" | jq -r '[.[]|.delay|if endswith("m") then (rtrimstr("m")|tonumber*60) else (rtrimstr("s")|tonumber) end|1/.]|add*100|round/100|"NVPS der drei Items zusammen: \(.)  (= 1/60 + 1/5 + 1/2)"'
step "3. Housekeeping: Aufbewahrungszeiten lesen und ändern"
api housekeeping.get '{"output":["hk_events_mode","hk_history_mode","hk_history","hk_trends_mode","hk_trends","hk_events_trigger"]}' | jq -r '"Vorher: Verlauf \(.hk_history) (Modus \(.hk_history_mode)), Trends \(.hk_trends), Trigger-Ereignisse \(.hk_events_trigger)"'
api housekeeping.update '{"hk_history":"7d","hk_trends":"90d"}' >/dev/null
api housekeeping.get '{"output":["hk_history","hk_trends"]}' | jq -r '"Nachher: Verlauf \(.hk_history), Trends \(.hk_trends)"'
echo "Fehlerbild: ungültige Angabe „abc“ für die Aufbewahrungszeit:"; api housekeeping.update '{"hk_history":"abc"}' 2>&1 | sed 's/^/  /'
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_server -c $W/server.conf -R housekeeper_execute" 2>&1
sleep 3; echo "Protokoll: $(grep -c 'executing housekeeper' $W/server.log) Meldung(en) 'executing housekeeper'"
step "4. Sicherung der Konfiguration (ohne Messwert-Tabellen) mit pg_dump; Größe und Inhalt"
HOST_CNT=$(sql "select count(*) from hosts where flags=0"); ITEM_CNT=$(sql "select count(*) from items")
pg_dump -h 127.0.0.1 -p $PGP -U zabbix -Fc -f "$W/zabbix.dump" --exclude-table-data='history*' --exclude-table-data='trends*' --exclude-table-data='events' --exclude-table-data='event_*' --exclude-table-data='problem*' --exclude-table-data='alerts' zbxlab 2>&1 | head -3
echo "Sicherungsdatei vorhanden und nicht leer: $([ -s $W/zabbix.dump ] && echo ja)"
echo "Größe unter 10 MiB: $([ $(stat -c %s $W/zabbix.dump) -lt 10485760 ] && echo ja || echo nein)"
echo "Inhaltsverzeichnis des Dumps enthält die Tabelle hosts: $(pg_restore -l $W/zabbix.dump | grep -c 'TABLE DATA public hosts ')"
step "5. Wiederherstellung in einer neuen Datenbank und Vergleich"
su postgres -c "psql -h 127.0.0.1 -p $PGP -qc 'DROP DATABASE IF EXISTS zbxrestore WITH (FORCE)' -c 'CREATE DATABASE zbxrestore OWNER zabbix'" >/dev/null 2>&1
pg_restore -h 127.0.0.1 -p $PGP -U zabbix -d zbxrestore --no-owner "$W/zabbix.dump" 2>&1 | head -3
DB=zbxrestore; R_HOST=$(sql "select count(*) from hosts where flags=0"); R_ITEM=$(sql "select count(*) from items"); R_HIST=$(sql "select count(*) from history")
echo "Hosts und Vorlagen: Original $HOST_CNT, Wiederherstellung $R_HOST; Items: $ITEM_CNT / $R_ITEM; gleich: $([ "$HOST_CNT" = "$R_HOST" ] && echo ja || echo nein)"
echo "Host zbx-intern in der Wiederherstellung: $(sql "select host from hosts where host='zbx-intern'")"
echo "Messwerte (history) in der Wiederherstellung: $R_HIST (bewusst nicht gesichert)"
step "6. Zweiter Server auf der wiederhergestellten Datenbank (anderer Port): startet er?"
mkdir -p "$W/r"; chown zabbix "$W/r"; sed -e "s#^DBName=.*#DBName=zbxrestore#; s#^ListenPort=.*#ListenPort=11061#; s#^LogFile=.*#LogFile=$W/r/server.log#; s#^PidFile=.*#PidFile=$W/r/server.pid#; s#^SocketDir=.*#SocketDir=$W/r#" "$W/server.conf" > "$W/r/server.conf"
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_server -c $W/r/server.conf"; waitfor "grep -q 'main process' $W/r/server.log"
sed -E 's/^ *[0-9]+:[0-9]+:[0-9]+\.[0-9]+ //' "$W/r/server.log" | grep -E "current database version|main process\]"
DB=zbxlab
step "7. Abschlussprojekt – Abnahmeprüfung (je Prüfpunkt OK/FEHLER)"
chk() { if eval "$2" >/dev/null 2>&1; then echo "OK      $1"; else echo "FEHLER  $1"; fi; }
chk "Server antwortet auf der API"          "[ \"\$(api0 apiinfo.version)\" = '\"7.0.32\"' ]"
chk "Agent erreichbar (zabbix_get)"         "[ \"\$($ZBX/bin/zabbix_get -s 127.0.0.1 -p $AGP -k agent.ping)\" = 1 ]"
chk "Interne Items liefern Werte"           "[ -n \"\$(hist $Q)\" ]"
chk "Housekeeping geändert (7d)"            "[ \"\$(api housekeeping.get '{\"output\":[\"hk_history\"]}' | jq -r .hk_history)\" = 7d ]"
chk "Sicherung vorhanden"                   "[ -s $W/zabbix.dump ]"
chk "Wiederherstellung vollständig"         "[ \"$HOST_CNT\" = \"$R_HOST\" ]"
chk "Zweiter Server startet"                "grep -q 'main process' $W/r/server.log"
chk "absichtlich falsch: Port 1"            "curl -sf http://127.0.0.1:1/"
pkill -f "$W/r/server.conf"
