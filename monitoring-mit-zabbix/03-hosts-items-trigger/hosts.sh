#!/usr/bin/env bash
# Modul 3: Hosts, Items und Trigger über die API anlegen und das Verhalten beobachten (echter Zabbix 7.0.32).
. "$(dirname "$0")/../lab.sh"
lab_up
echo 'UserParameter=uebung.warteschlange,cat /tmp/p17/queue.txt' > "$W/agent.d/uebung.conf"; echo 10 > "$W/queue.txt"; restart_agent
step "1. Host-Gruppe und Host anlegen (Agent-Schnittstelle 127.0.0.1:$AGP)"
GID=$(api hostgroup.create '{"name":"Uebung-Linux"}' | jq -r '.groupids[0]')
HID=$(api host.create "{\"host\":\"lin01\",\"name\":\"Linux-Server 01\",\"groups\":[{\"groupid\":\"$GID\"}],\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"127.0.0.1\",\"dns\":\"\",\"port\":\"$AGP\"}]}" | jq -r '.hostids[0]')
api host.get "{\"hostids\":\"$HID\",\"output\":[\"host\",\"name\",\"status\"],\"selectInterfaces\":[\"type\",\"ip\",\"port\"],\"selectHostGroups\":[\"name\"]}" | jq -r '.[0]|"Host: \(.host) (\(.name)), Status \(.status) (0 = überwacht), Schnittstelle \(.interfaces[0].ip):\(.interfaces[0].port), Gruppe \(.hostgroups[0].name)"'
step "2. Items anlegen: Schlüssel, Datentyp und Intervall"
mkitem() { api item.create "{\"hostid\":\"$HID\",\"name\":\"$1\",\"key_\":\"$2\",\"type\":0,\"value_type\":$3,\"delay\":\"2s\",\"interfaceid\":\"$(api host.get "{\"hostids\":\"$HID\",\"selectInterfaces\":[\"interfaceid\"]}" | jq -r '.[0].interfaces[0].interfaceid')\"}" | jq -r '.itemids[0]'; }
I_PING=$(mkitem "Agent erreichbar" agent.ping 3)
I_LOAD=$(mkitem "Last (1 Minute)" 'system.cpu.load[all,avg1]' 0)
I_Q=$(mkitem "Warteschlange" uebung.warteschlange 3)
I_BAD=$(mkitem "Fehlerhafter Schlüssel" kein.schluessel 3)
api item.get "{\"hostids\":\"$HID\",\"output\":[\"name\",\"key_\",\"value_type\",\"delay\"],\"sortfield\":\"name\"}" | jq -r '.[]|"  \(.key_)\tTyp \(.value_type)\tIntervall \(.delay)\t\(.name)"'
echo "(value_type: 0 = Fließkomma, 3 = ganze Zahl ohne Vorzeichen)"
step "3. Erste Werte treffen ein; das Item mit dem falschen Schlüssel wird „nicht unterstützt“"
printf 'agent.ping = %s\n' "$(wait_val $I_PING)"; printf 'uebung.warteschlange = %s\n' "$(wait_val $I_Q)"
v=$(wait_val $I_LOAD); echo "system.cpu.load[all,avg1] liefert einen Wert: $([ -n "$v" ] && [ "$v" != KEIN-WERT ] && echo ja)"
for _ in $(seq 1 60); do [ "$(sql "select state from item_rtdata where itemid=$I_BAD")" = 1 ] && break; sleep 0.5; done
api item.get "{\"itemids\":\"$I_BAD\",\"output\":[\"state\",\"error\"]}" | jq -r '.[0]|"kein.schluessel: state=\(.state) (1 = nicht unterstützt), Fehler: \(.error)"'
step "4. Trigger mit Ausdruck und Wiederherstellungsausdruck (Hysterese)"
T1=$(api trigger.create '{"description":"Warteschlange zu lang","expression":"last(/lin01/uebung.warteschlange)>100","recovery_mode":1,"recovery_expression":"last(/lin01/uebung.warteschlange)<50","priority":3}' | jq -r '.triggerids[0]')
api trigger.get "{\"triggerids\":\"$T1\",\"output\":[\"description\",\"expression\",\"recovery_expression\",\"priority\",\"value\"],\"expandExpression\":false}" | jq -r '.[0]|"Trigger: \(.description)\n  Problem ab:  \(.expression)\n  Erholt bei:  \(.recovery_expression)\n  Priorität \(.priority) (3 = Durchschnitt), Wert \(.value) (0 = OK)"'
echo "Trigger mit falschem Ausdruck:"; api trigger.create '{"description":"kaputt","expression":"last(/lin01/gibt.es.nicht)>1"}' 2>&1 | sed 's/^/  /'
api trigger.create '{"description":"kaputt","expression":"last(/lin01/uebung.warteschlange>1"}' 2>&1 | sed 's/^/  /'
step "5. Ablauf: Wert 150 -> Problem; 70 -> bleibt Problem (Hysterese); 20 -> OK"
echo 150 > "$W/queue.txt"; wait_trig $T1 1 && echo "Wert 150: Trigger = PROBLEM"
echo "Aktives Problem: $(api problem.get '{"output":["name","severity"]}' | jq -r '.[0]|"\(.name) (Schweregrad \(.severity))"')"
echo 70 > "$W/queue.txt"; sleep 8; echo "Wert 70: Trigger-Wert = $(sql "select value from triggers where triggerid=$T1") (1 = Problem bleibt, weil 70 nicht unter 50 liegt)"
echo 20 > "$W/queue.txt"; wait_trig $T1 0 && echo "Wert 20: Trigger = OK"
step "6. Ereignisverlauf (Tabelle events): Problem und Wiederherstellung"
sql "select case value when 1 then 'PROBLEM' else 'OK' end from events where source=0 and object=0 and objectid=$T1 order by eventid" | sed 's/^/  /'
echo "Problem-Einträge jetzt offen: $(api problem.get '{"countOutput":true}' | tr -d '"')"
