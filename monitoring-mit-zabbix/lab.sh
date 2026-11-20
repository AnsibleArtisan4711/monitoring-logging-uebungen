#!/usr/bin/env bash
# Gemeinsame Hilfen der Übungsreihe (P17). Echte Programme: Zabbix-Server, Zabbix-Agent, zabbix_get/sender, Frontend/API (PHP), PostgreSQL, snmpd.
# Zabbix 7.0.32 wurde aus dem Quellcode gebaut (Installationsort /opt/zbx/inst, Frontend /opt/zbx/ui); Ubuntu 24.04 hat keine Zabbix-Pakete.
# Jede Übung arbeitet mit einer frischen Datenbank "zbxlab" (Kopie der leeren Zabbix-Datenbank "zbx_base").
W=/tmp/p17; HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZBX=/opt/zbx/inst; UI=/opt/zbx/ui; PGB=/usr/lib/postgresql/16/bin; PGP=15432
SRVP=11051; AGP=11050; WEB=18080; SNMPP=11161
export PGPASSWORD=uebung-zbx
step() { echo; echo "## $*"; }
cmd() { echo "\$ $*"; "$@" 2>&1; return $?; }
sql() { psql -h 127.0.0.1 -p $PGP -U zabbix -d "${DB:-zbxlab}" -tA -F $'\t' -c "$1"; }
waitfor() { for _ in $(seq 1 80); do eval "$1" >/dev/null 2>&1 && return 0; sleep 0.5; done; echo "TIMEOUT $1"; return 1; }
lab_down() { pkill -f "$ZBX/sbin/zabbix_server" 2>/dev/null; pkill -f "$ZBX/sbin/zabbix_agentd" 2>/dev/null; pkill -f "php.*127.0.0.1:$WEB" 2>/dev/null; pkill -f "snmpd.*$SNMPP" 2>/dev/null
  for _ in $(seq 1 20); do pgrep -f "$ZBX/sbin/zabbix_" >/dev/null || break; sleep 0.5; done; pkill -9 -f "$ZBX/sbin/zabbix_" 2>/dev/null; sleep 1; rm -rf "$W"; }
trap 'lab_down >/dev/null 2>&1' EXIT
pg_up() { su postgres -c "psql -h 127.0.0.1 -p $PGP -tc 'select 1'" >/dev/null 2>&1 || su postgres -c "$PGB/pg_ctl -D /opt/zbx/pg/data -o '-p $PGP -c listen_addresses=127.0.0.1 -c unix_socket_directories=/tmp' -l /opt/zbx/pg/pg.log -w start" >/dev/null; }
mk_conf() {
  mkdir -p "$W" "$W/alertscripts"; chown zabbix "$W" "$W/alertscripts"
  cat > "$W/server.conf" <<C
LogFile=$W/server.log
PidFile=$W/server.pid
SocketDir=$W
ListenPort=$SRVP
DBHost=127.0.0.1
DBPort=$PGP
DBName=${DBN:-zbxlab}
DBUser=zabbix
DBPassword=uebung-zbx
StartPollers=2
StartPingers=1
StartTrappers=2
StartDiscoverers=1
CacheSize=32M
HistoryCacheSize=16M
CacheUpdateFrequency=5
Timeout=3
UnreachablePeriod=5
UnreachableDelay=2
UnavailableDelay=5
AlertScriptsPath=$W/alertscripts
C
  cat > "$W/agent.conf" <<C
LogFile=$W/agent.log
PidFile=$W/agent.pid
Server=127.0.0.1
ServerActive=127.0.0.1:$SRVP
ListenPort=$AGP
Hostname=lin01
RefreshActiveChecks=10
Include=$W/agent.d/*.conf
C
  mkdir -p "$W/agent.d"
  cat > "$UI/conf/zabbix.conf.php" <<C
<?php
\$DB['TYPE']='POSTGRESQL';\$DB['SERVER']='127.0.0.1';\$DB['PORT']='$PGP';\$DB['DATABASE']='${DBN:-zbxlab}';\$DB['USER']='zabbix';\$DB['PASSWORD']='uebung-zbx';
\$DB['SCHEMA']='';\$DB['ENCRYPTION']=false;\$DB['KEY_FILE']='';\$DB['CERT_FILE']='';\$DB['CA_FILE']='';\$DB['VERIFY_HOST']=false;\$DB['CIPHER_LIST']='';\$DB['VAULT']='';\$DB['VAULT_URL']='';\$DB['VAULT_DB_PATH']='';\$DB['VAULT_TOKEN']='';\$DB['VAULT_CERT_FILE']='';\$DB['VAULT_KEY_FILE']='';\$DB['DOUBLE_IEEE754']=true;
\$ZBX_SERVER='127.0.0.1';\$ZBX_SERVER_PORT='$SRVP';\$ZBX_SERVER_NAME='uebung';
\$IMAGE_FORMAT_DEFAULT=IMAGE_FORMAT_PNG;
C
}
start_server() { su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_server -c $W/server.conf"; waitfor "grep -q 'server #1 started' $W/server.log || grep -q 'thread started' $W/server.log"; }
start_agent() { su -s /bin/bash zabbix -c "$ZBX/sbin/zabbix_agentd -c $W/agent.conf"; waitfor "$ZBX/bin/zabbix_get -s 127.0.0.1 -p $AGP -k agent.ping | grep -q 1"; }
start_web() { nohup php -d post_max_size=16M -d max_execution_time=300 -d max_input_time=300 -d date.timezone=Europe/Berlin -S 127.0.0.1:$WEB -t "$UI" >"$W/php.log" 2>&1 & waitfor "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$WEB/index.php | grep -q 200"; }
# JSON-RPC: api methode 'params-json' -> Ergebnis als JSON (Fehler: Meldung nach stderr, Rückgabecode 1)
api() { local r; r=$(curl -s -X POST "http://127.0.0.1:$WEB/api_jsonrpc.php" -H 'Content-Type: application/json-rpc' ${TOKEN:+-H "Authorization: Bearer $TOKEN"} -d "{\"jsonrpc\":\"2.0\",\"method\":\"$1\",\"params\":${2:-{\}},\"id\":1}");
  if echo "$r" | jq -e .error >/dev/null 2>&1; then echo "API-FEHLER $1: $(echo "$r" | jq -r '.error.data // .error.message')" >&2; return 1; fi; echo "$r" | jq -c .result; }
lab_up() {
  lab_down >/dev/null 2>&1; pg_up
  su postgres -c "psql -h 127.0.0.1 -p $PGP -qc 'DROP DATABASE IF EXISTS zbxlab WITH (FORCE)' -c 'CREATE DATABASE zbxlab TEMPLATE zbx_base OWNER zabbix'" >/dev/null
  mk_conf; start_server; start_agent; start_web
  TOKEN=$(curl -s -X POST "http://127.0.0.1:$WEB/api_jsonrpc.php" -H 'Content-Type: application/json-rpc' -d '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"zabbix"},"id":1}' | jq -r .result)
  [ ${#TOKEN} = 32 ] || { echo "ANMELDUNG-FEHLGESCHLAGEN"; return 1; }
  # Der vorinstallierte Host "Zabbix server" wird abgeschaltet (er würde Port 10050 abfragen)
  api host.update '{"hostid":"10084","status":1}' >/dev/null
}
api0() { curl -s -X POST "http://127.0.0.1:$WEB/api_jsonrpc.php" -H 'Content-Type: application/json-rpc' -d "{\"jsonrpc\":\"2.0\",\"method\":\"$1\",\"params\":${2:-[]},\"id\":1}" | jq -c .result; }
# Wartet, bis ein Item einen Wert hat (history/history_uint/history_str/history_text); Argument: itemid
hist() { [ -n "$1" ] || return 1; sql "select value from (select clock,value::text from history where itemid=$1 union all select clock,value::text from history_uint where itemid=$1 union all select clock,value from history_str where itemid=$1 union all select clock,value from history_text where itemid=$1) h order by clock desc limit 1"; }
wait_val() { for _ in $(seq 1 120); do v=$(hist "$1"); [ -n "$v" ] && { echo "$v"; return 0; }; sleep 0.5; done; echo "KEIN-WERT"; return 1; }
itemid() { api item.get "{\"output\":[\"itemid\"],\"filter\":{\"key_\":\"$2\"},\"hostids\":\"$1\"}" | jq -r '.[0].itemid'; }
restart_agent() { pkill -f "$ZBX/sbin/zabbix_agentd"; for _ in $(seq 1 20); do pgrep -f "$ZBX/sbin/zabbix_agentd" >/dev/null || break; sleep 0.3; done; rm -f "$W/agent.pid"; start_agent; }
# wartet, bis ein Trigger den Wert $2 hat (0 = OK, 1 = Problem); Argument 1: triggerid
wait_trig() { for _ in $(seq 1 160); do [ "$(sql "select value from triggers where triggerid=$1")" = "$2" ] && return 0; sleep 0.5; done; echo "TIMEOUT-Trigger $1"; return 1; }
