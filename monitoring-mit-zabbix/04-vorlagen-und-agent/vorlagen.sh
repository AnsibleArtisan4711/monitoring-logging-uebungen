#!/usr/bin/env bash
# Modul 4: Vorlagen, Makros, aktive Agentenprüfungen, Trapper und zabbix_sender, Vorverarbeitung (echter Zabbix 7.0.32).
. "$(dirname "$0")/../lab.sh"
lab_up
printf 'UserParameter=uebung.warteschlange,cat %s/queue.txt\nUserParameter=uebung.kib,cat %s/kib.txt\n' "$W" "$W" > "$W/agent.d/uebung.conf"; echo 10 > "$W/queue.txt"; echo 2048 > "$W/kib.txt"; restart_agent
step "1. Vorlage mit Item, Makro und Trigger anlegen"
TG=$(api templategroup.create '{"name":"Uebung-Vorlagen"}' | jq -r '.groupids[0]')
TID=$(api template.create "{\"host\":\"Uebung Linux Basis\",\"groups\":[{\"groupid\":\"$TG\"}],\"macros\":[{\"macro\":\"{\$QUEUE_MAX}\",\"value\":\"100\"}]}" | jq -r '.templateids[0]')
api item.create "{\"hostid\":\"$TID\",\"name\":\"Warteschlange\",\"key_\":\"uebung.warteschlange\",\"type\":0,\"value_type\":3,\"delay\":\"2s\"}" >/dev/null
api item.create "{\"hostid\":\"$TID\",\"name\":\"Speicher in Byte (aus KiB)\",\"key_\":\"uebung.kib\",\"type\":0,\"value_type\":3,\"delay\":\"2s\",\"preprocessing\":[{\"type\":\"1\",\"params\":\"1024\",\"error_handler\":\"0\",\"error_handler_params\":\"\"}]}" >/dev/null
api trigger.create '{"description":"Warteschlange über {$QUEUE_MAX}","expression":"last(/Uebung Linux Basis/uebung.warteschlange)>{$QUEUE_MAX}","priority":2}' >/dev/null
api template.get "{\"templateids\":\"$TID\",\"output\":[\"host\"],\"selectItems\":[\"key_\"],\"selectTriggers\":[\"description\"],\"selectMacros\":[\"macro\",\"value\"]}" | jq -r '.[0]|"Vorlage \(.host): Items \(.items|map(.key_)|join(", ")); Trigger \"\(.triggers[0].description)\"; Makro \(.macros[0].macro)=\(.macros[0].value)"'
step "2. Vorlage mit einem Host verknüpfen: Items und Trigger werden geerbt"
GID=$(api hostgroup.create '{"name":"Uebung-Linux"}' | jq -r '.groupids[0]')
HID=$(api host.create "{\"host\":\"lin01\",\"groups\":[{\"groupid\":\"$GID\"}],\"templates\":[{\"templateid\":\"$TID\"}],\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"127.0.0.1\",\"dns\":\"\",\"port\":\"$AGP\"}]}" | jq -r '.hostids[0]')
api item.get "{\"hostids\":\"$HID\",\"output\":[\"key_\",\"templateid\"],\"sortfield\":\"key_\"}" | jq -r '.[]|"  Item \(.key_) geerbt von Vorlagen-Item \(if .templateid!="0" then "ja" else "nein" end)"'
echo "  Trigger am Host: $(api trigger.get "{\"hostids\":\"$HID\",\"output\":[\"description\"],\"expandDescription\":true}" | jq -r '.[0].description')"
IQ=$(itemid $HID uebung.warteschlange); IK=$(itemid $HID uebung.kib)
step "3. Vorverarbeitung: Multiplikator 1024 macht aus 2048 KiB den Wert in Byte"
printf 'Rohwert in der Datei: 2048, gespeicherter Wert: %s\n' "$(wait_val $IK)"
step "4. Makro auf Host-Ebene überschreibt das Makro der Vorlage"
echo 50 > "$W/queue.txt"; sleep 10
TR=$(api trigger.get "{\"hostids\":\"$HID\",\"output\":[\"triggerid\",\"value\"]}" | jq -r '.[0].triggerid')
echo "Warteschlange 50, Grenze aus der Vorlage 100: Trigger-Wert = $(sql "select value from triggers where triggerid=$TR") (0 = OK)"
api usermacro.create "{\"hostid\":\"$HID\",\"macro\":\"{\$QUEUE_MAX}\",\"value\":\"30\"}" >/dev/null
wait_trig $TR 1 && echo "Host-Makro {\$QUEUE_MAX}=30: Trigger-Wert = 1 (Problem) bei gleichem Messwert 50"
echo "Aufgelöster Name des Problems: $(api problem.get '{"output":["name"]}' | jq -r '.[0].name')"
step "5. Aktive Prüfung: der Agent holt seine Liste und sendet Werte selbst (Item-Typ 7, Hostname muss passen)"
IA=$(api item.create "{\"hostid\":\"$HID\",\"name\":\"Hostname (aktiv)\",\"key_\":\"agent.hostname\",\"type\":7,\"value_type\":4,\"delay\":\"5s\"}" | jq -r '.itemids[0]')
printf 'agent.hostname (aktiv) = %s\n' "$(wait_val $IA)"
step "6. Trapper-Item und zabbix_sender: Werte von außen einliefern"
IT=$(api item.create "{\"hostid\":\"$HID\",\"name\":\"Manueller Wert\",\"key_\":\"uebung.manuell\",\"type\":2,\"value_type\":3,\"trapper_hosts\":\"127.0.0.1\"}" | jq -r '.itemids[0]')
sleep 6
echo "\$ zabbix_sender -z 127.0.0.1 -p $SRVP -s lin01 -k uebung.manuell -o 42"; $ZBX/bin/zabbix_sender -z 127.0.0.1 -p $SRVP -s lin01 -k uebung.manuell -o 42 2>&1 | grep -E "processed|sent"| sed -E 's/;? seconds spent.*//'
printf 'gespeicherter Wert: %s\n' "$(wait_val $IT)"
echo "\$ zabbix_sender ... -s unbekannt -k uebung.manuell -o 7"; $ZBX/bin/zabbix_sender -z 127.0.0.1 -p $SRVP -s unbekannt -k uebung.manuell -o 7 2>&1 | grep -E "processed|info from server" | sed -E 's/;? seconds spent.*//'
step "7. Mitgelieferte Vorlagen (Inhalt der frisch installierten Datenbank)"
for t in "Linux by Zabbix agent" "Windows by Zabbix agent" "Linux by SNMP" "ICMP Ping"; do api template.get "{\"output\":[\"host\"],\"filter\":{\"host\":\"$t\"},\"selectItems\":\"count\",\"selectTriggers\":\"count\",\"selectDiscoveries\":\"count\"}" | jq -r --arg t "$t" 'if length==0 then "  \($t): nicht gefunden" else .[0]|"  \(.host): \(.items) Items, \(.triggers) Trigger, \(.discoveries) Entdeckungsregeln" end'; done
step "8. Windows-Agent (NICHT ausgeführt): so würde der Host in Zabbix aussehen"
cat <<'T'
  Host win01, Schnittstelle Agent, Port 10050 (Standardport nach Fachwissen, nicht bestätigt), Vorlage "Windows by Zabbix agent".
  In der Agentenkonfiguration unter Windows: Server=<Adresse des Zabbix-Servers>, ServerActive=<Adresse>, Hostname=win01.
  Dienst "Zabbix Agent" starten; Namen von Dienst und Installationspfad nicht geprüft.
T
