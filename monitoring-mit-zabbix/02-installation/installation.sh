#!/usr/bin/env bash
# Modul 2: Installation und erste Inbetriebnahme. Hier wird NICHT aus Paketen installiert (Ubuntu 24.04 hat keine Zabbix-Pakete, repo.zabbix.com war nicht erreichbar):
# der Server ist aus dem Quellcode gebaut; geübt werden Datenbank, Konfiguration, Start, Prüfung und Fehlerbilder. Paketbefehle stehen nur als Text.
. "$(dirname "$0")/../lab.sh"
lab_down >/dev/null 2>&1; pg_up; mkdir -p "$W"; chown zabbix "$W"
SQLD=/opt/zbx/src/database/postgresql
step "1. Datenbank anlegen und Schema einspielen (schema.sql, images.sql, data.sql in dieser Reihenfolge)"
su postgres -c "psql -h 127.0.0.1 -p $PGP -qc 'DROP DATABASE IF EXISTS zbxinst WITH (FORCE)' -c \"CREATE DATABASE zbxinst OWNER zabbix ENCODING 'UTF8' TEMPLATE template0\"" >/dev/null 2>&1
for f in schema.sql images.sql data.sql; do psql -q -h 127.0.0.1 -p $PGP -U zabbix -d zbxinst -v ON_ERROR_STOP=1 -f $SQLD/$f >/dev/null 2>&1 && echo "$f eingespielt" || echo "$f FEHLER"; done
DB=zbxinst
echo "Tabellen: $(sql "select count(*) from information_schema.tables where table_schema='public'")"
echo "Datenbankversion (Tabelle dbversion): $(sql 'select mandatory,optional from dbversion' | tr '\t' ' ')"
step "2. Fehlerbild: Server mit falschem Datenbankanschluss (Port 15999) starten (Auszug des Protokolls)"
DBN=zbxinst mk_conf; DB=zbxinst
sed 's/^DBPort=.*/DBPort=15999/' "$W/server.conf" > "$W/server-falsch.conf"
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_server -c $W/server-falsch.conf" 2>&1 | head -3; sleep 4
sed -E 's/^ *[0-9]+:[0-9]+:[0-9]+\.[0-9]+ //; s/\(revision [^)]*\)/(revision …)/' "$W/server.log" | grep -E "Starting Zabbix Server|cannot connect|connection to database|failed|refused" | sort -u | cut -c1-170
pkill -f "$ZBX/sbin/zabbix_server"; sleep 2; pgrep -f "$ZBX/sbin/zabbix_server" >/dev/null && echo "Server läuft noch" || echo "Server beendet"
rm -f "$W/server.log" "$W/server.pid"
step "3. Richtige Konfiguration: Server starten, Startmeldungen im Protokoll"
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_server -c $W/server.conf"; waitfor "grep -q 'thread started' $W/server.log"; sleep 2
sed -E 's/^ *[0-9]+:[0-9]+:[0-9]+\.[0-9]+ //' "$W/server.log" | grep -E "Starting Zabbix Server|current database version|main process\]" | sed -E 's/\(revision [^)]*\)/(revision …)/' | cut -c1-150
echo "Konfiguration (ohne Kennwort):"; grep -vE "^(#|$)|Password" "$W/server.conf" | sed 's/^/  /'
step "4. Agent konfigurieren und mit dem Testschalter -t prüfen (ohne Dienst zu starten)"
cat > "$W/agent.conf" <<C
LogFile=$W/agent.log
Server=127.0.0.1
ServerActive=127.0.0.1:$SRVP
ListenPort=$AGP
Hostname=lin01
C
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_agentd -c $W/agent.conf -t agent.ping" 2>&1
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_agentd -c $W/agent.conf -t agent.hostname" 2>&1
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_agentd -c $W/agent.conf -t kein.schluessel" 2>&1
step "5. Frontend: PHP-Module, Konfigurationsdatei und Anmeldung über die API"
for m in pgsql bcmath mbstring gd xml curl; do php -m | grep -qix "$m" && echo "PHP-Modul $m: vorhanden" || echo "PHP-Modul $m: FEHLT"; done
DBN=zbxinst mk_conf; start_web
echo "Anmeldung mit falschem Kennwort: $(curl -s -X POST http://127.0.0.1:$WEB/api_jsonrpc.php -H 'Content-Type: application/json-rpc' -d '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"x"},"id":1}' | jq -r '.error.data')"
T=$(curl -s -X POST http://127.0.0.1:$WEB/api_jsonrpc.php -H 'Content-Type: application/json-rpc' -d '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"zabbix"},"id":1}' | jq -r .result)
echo "Anmeldung mit Standardkennwort: $([ ${#T} = 32 ] && echo 'erfolgreich (Token mit 32 Zeichen)')  -> Standardkennwort sofort ändern!"
TOKEN=$T; api user.update '{"userid":"1","current_passwd":"zabbix","passwd":"Uebung-Neu-2026!"}' >/dev/null 2>&1 && echo "Kennwort geändert: ja" || echo "Kennwort geändert: nein"
printf 'altes Kennwort danach: '; curl -s -X POST http://127.0.0.1:$WEB/api_jsonrpc.php -H 'Content-Type: application/json-rpc' -d '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"zabbix"},"id":1}' | jq -r '.error.data'
step "6. Laufzeitbefehle des Servers (-R): Konfiguration neu laden, Protokollstufe ändern"
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_server -c $W/server.conf -R config_cache_reload" 2>&1
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_server -c $W/server.conf -R log_level_increase=housekeeper" 2>&1
su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_server -c $W/server.conf -R kein_befehl" 2>&1 | head -2 | sed -E 's/\[[0-9]+\]/[PID]/'
step "7. Installation aus Paketen (NICHT ausgeführt; Paketnamen und Ablauf aus Fachwissen, nicht bestätigt)"
cat <<'T'
  1. Paket mit der Repository-Konfiguration von zabbix.com herunterladen und installieren (Version und Betriebssystem wählen).
  2. apt update
  3. apt install zabbix-server-pgsql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent
  4. Datenbank und Benutzer anlegen, Schema aus den SQL-Skripten des Pakets einspielen.
  5. DBPassword in /etc/zabbix/zabbix_server.conf eintragen; Dienste mit systemctl starten und aktivieren.
  6. Frontend im Browser aufrufen (Einrichtungsassistent), Standardkennwort ändern.
T
