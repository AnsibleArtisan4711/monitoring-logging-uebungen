#!/usr/bin/env bash
# Modul 5: SNMP-Überwachung mit Zabbix. Echt: snmpd 5.9.4 (Loopback, Port 11161), snmpget/snmpwalk, Zabbix-SNMP-Poller. Keine echten Netzwerkgeräte.
. "$(dirname "$0")/../lab.sh"
lab_up
cat > "$W/snmpd.conf" <<C
agentAddress udp:127.0.0.1:$SNMPP
rocommunity uebung 127.0.0.1
sysName lin-snmp01
sysContact it@example.org
sysLocation Uebungsraum
C
snmpd -C -c "$W/snmpd.conf" -p "$W/snmpd.pid" -Lf "$W/snmpd.log" 2>&1; sleep 1
S="127.0.0.1:$SNMPP"
step "1. SNMP von Hand prüfen (snmpget, snmpwalk), bevor Zabbix es nutzt"
echo "\$ snmpget -v2c -c uebung -On $S 1.3.6.1.2.1.1.5.0"; snmpget -v2c -c uebung -On $S 1.3.6.1.2.1.1.5.0
echo "\$ snmpget -v2c -c uebung -On $S 1.3.6.1.2.1.1.4.0 1.3.6.1.2.1.1.6.0"; snmpget -v2c -c uebung -On $S 1.3.6.1.2.1.1.4.0 1.3.6.1.2.1.1.6.0
echo "\$ snmpwalk -v2c -c uebung -On $S 1.3.6.1.2.1.2.2.1.2   (Schnittstellennamen, ifDescr, erste Zeile)"; snmpwalk -v2c -c uebung -On $S 1.3.6.1.2.1.2.2.1.2 | head -1
echo "\$ snmpget -v2c -c falsch $S 1.3.6.1.2.1.1.5.0"; timeout 10 snmpget -v2c -c falsch -t 1 -r 0 $S 1.3.6.1.2.1.1.5.0 2>&1
echo "\$ snmpget -v1 -c uebung $S 1.3.6.1.2.1.1.5.0   (Version 1 mit richtiger Gemeinschaft)"; snmpget -v1 -c uebung -On $S 1.3.6.1.2.1.1.5.0
step "2. Host mit SNMP-Schnittstelle (Version 2c, Gemeinschaft über Makro)"
GID=$(api hostgroup.create '{"name":"Uebung-Netzwerk"}' | jq -r '.groupids[0]')
mkhost() { api host.create "{\"host\":\"$1\",\"groups\":[{\"groupid\":\"$GID\"}],\"macros\":[{\"macro\":\"{\$SNMP_COMMUNITY}\",\"value\":\"$2\"}],\"interfaces\":[{\"type\":2,\"main\":1,\"useip\":1,\"ip\":\"127.0.0.1\",\"dns\":\"\",\"port\":\"$SNMPP\",\"details\":{\"version\":2,\"bulk\":1,\"community\":\"{\$SNMP_COMMUNITY}\"}}]}" | jq -r '.hostids[0]'; }
H1=$(mkhost switch01 uebung); H2=$(mkhost switch02 falsch)
api host.get "{\"hostids\":\"$H1\",\"output\":[\"host\"],\"selectInterfaces\":[\"type\",\"port\",\"details\"]}" | jq -r '.[0]|"Host \(.host): Schnittstellentyp \(.interfaces[0].type) (2 = SNMP), Version \(.interfaces[0].details.version), Gemeinschaft \(.interfaces[0].details.community), Bulk \(.interfaces[0].details.bulk)"'
step "3. SNMP-Items: OID, Datentyp, Vorverarbeitung (Änderung je Sekunde)"
IF1=$(api host.get "{\"hostids\":\"$H1\",\"selectInterfaces\":[\"interfaceid\"]}" | jq -r '.[0].interfaces[0].interfaceid')
IF2=$(api host.get "{\"hostids\":\"$H2\",\"selectInterfaces\":[\"interfaceid\"]}" | jq -r '.[0].interfaces[0].interfaceid')
snmpitem() { api item.create "{\"hostid\":\"$1\",\"interfaceid\":\"$2\",\"name\":\"$3\",\"key_\":\"$4\",\"type\":20,\"snmp_oid\":\"$5\",\"value_type\":$6,\"delay\":\"3s\"$7}" | jq -r '.itemids[0]'; }
A=$(snmpitem $H1 $IF1 "Systemname" sysname 1.3.6.1.2.1.1.5.0 4)
B=$(snmpitem $H1 $IF1 "Ansprechpartner" syscontact 1.3.6.1.2.1.1.4.0 4)
C=$(snmpitem $H1 $IF1 "Anzahl Schnittstellen" ifnumber 1.3.6.1.2.1.2.1.0 3)
D=$(snmpitem $H1 $IF1 "Eingehende Oktette lo je Sekunde" 'inoctets[lo]' 1.3.6.1.2.1.2.2.1.10.1 0 ',"preprocessing":[{"type":"10","params":"","error_handler":"0","error_handler_params":""}]')
E=$(snmpitem $H2 $IF2 "Systemname (falsche Gemeinschaft)" sysname 1.3.6.1.2.1.1.5.0 4)
F=$(snmpitem $H1 $IF1 "Nicht vorhandene OID" kaputt 1.3.6.1.2.1.99.99.0 4)
printf 'switch01 sysname      = %s\n' "$(wait_val $A)"
printf 'switch01 syscontact   = %s\n' "$(wait_val $B)"
printf 'switch01 ifnumber ist eine ganze Zahl größer 0: %s\n' "$(v=$(wait_val $C); [ "$v" -gt 0 ] 2>/dev/null && echo ja || echo nein)"
v=$(wait_val $D); echo "inoctets[lo] (Änderung je Sekunde) ist eine Zahl größer oder gleich 0: $(awk -v v="$v" 'BEGIN{print (v+0>=0 && v!="KEIN-WERT")?"ja":"nein"}')"
step "4. Fehlerbilder: falsche Gemeinschaft und fehlende OID"
for _ in $(seq 1 100); do [ -n "$(sql "select error from item_rtdata where itemid=$F")" ] && [ -n "$(sql "select error from interface where hostid=$H2")" ] && break; sleep 1; done
echo "  switch02 (falsche Gemeinschaft), Fehler an der Schnittstelle: $(sql "select error from interface where hostid=$H2" | sed -E 's/ *(for|from) .*//; s/"[^"]*"/"…"/g')"
echo "  switch01 (OID fehlt), Fehler am Item: $(sql "select error from item_rtdata where itemid=$F")"
echo "Verfügbarkeit der SNMP-Schnittstellen (1 = verfügbar, 2 = nicht verfügbar):"
for h in $H1 $H2; do for _ in $(seq 1 60); do [ "$(sql "select available from interface where hostid=$h")" != 0 ] && break; sleep 1; done; printf '  %s: %s\n' "$(sql "select host from hosts where hostid=$h")" "$(sql "select available from interface where hostid=$h")"; done
step "5. Mitgelieferte SNMP-Vorlage (Linux by SNMP): Entdeckungsregeln"
api template.get '{"output":["host"],"filter":{"host":"Linux by SNMP"},"selectDiscoveries":["name","key_"]}' | jq -r '.[0].discoveries[]|"  \(.name)  (\(.key_))"' | sort | head -6
step "6. SNMPv3 und Traps (NICHT ausgeführt)"
cat <<'T'
  SNMPv3 (Benutzername, Authentifizierung, Verschlüsselung) und SNMP-Traps wurden nicht getestet; Feldnamen und Optionen sind nicht bestätigt.
T
