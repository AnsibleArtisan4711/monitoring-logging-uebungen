#!/usr/bin/env bash
# Modul 7: Medientyp (Skript), Benutzer-Medium, Aktion, Wartungsfenster, Dashboard (echter Zabbix 7.0.32; kein E-Mail-Versand, nur ein Skript, das in eine Datei schreibt).
. "$(dirname "$0")/../lab.sh"
lab_up
echo 10 > "$W/queue.txt"; echo "UserParameter=uebung.warteschlange,cat $W/queue.txt" > "$W/agent.d/uebung.conf"; restart_agent
cat > "$W/alertscripts/meldung.sh" <<S
#!/bin/bash
# Parameter 1 = Empfänger, 2 = Betreff, 3 = Text
echo "AN=\$1 | BETREFF=\$2" >> $W/meldungen.log
S
chmod 755 "$W/alertscripts/meldung.sh"; chown zabbix "$W/alertscripts/meldung.sh"; : > "$W/meldungen.log"; chown zabbix "$W/meldungen.log"
step "1. Medientyp „Skript“ anlegen und dem Benutzer Admin zuordnen"
MT=$(api mediatype.create '{"name":"Datei-Skript","type":1,"status":0,"exec_path":"meldung.sh","parameters":[{"sortorder":"0","value":"{ALERT.SENDTO}"},{"sortorder":"1","value":"{ALERT.SUBJECT}"},{"sortorder":"2","value":"{ALERT.MESSAGE}"}]}' | jq -r '.mediatypeids[0]')
api user.update "{\"userid\":\"1\",\"medias\":[{\"mediatypeid\":\"$MT\",\"sendto\":[\"bereitschaft\"],\"active\":0,\"severity\":63,\"period\":\"1-7,00:00-24:00\"}]}" >/dev/null
api mediatype.get "{\"mediatypeids\":\"$MT\",\"output\":[\"name\",\"type\",\"exec_path\"]}" | jq -r '.[0]|"Medientyp \(.name), Typ \(.type) (1 = Skript), Skript \(.exec_path)"'
api user.get '{"userids":"1","output":["username"],"selectMedias":["sendto","severity","period"]}' | jq -r '.[0]|"Benutzer \(.username): Empfänger \(.medias[0].sendto), Schweregrade-Maske \(.medias[0].severity), Zeitraum \(.medias[0].period)"'
step "2. Host, Trigger und Aktion (Problem ab Durchschnitt: Nachricht; Wiederherstellung: Nachricht)"
GID=$(api hostgroup.create '{"name":"Uebung-Linux"}' | jq -r '.groupids[0]')
HID=$(api host.create "{\"host\":\"lin01\",\"groups\":[{\"groupid\":\"$GID\"}],\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"127.0.0.1\",\"dns\":\"\",\"port\":\"$AGP\"}]}" | jq -r '.hostids[0]')
IFID=$(api host.get "{\"hostids\":\"$HID\",\"selectInterfaces\":[\"interfaceid\"]}" | jq -r '.[0].interfaces[0].interfaceid')
api item.create "{\"hostid\":\"$HID\",\"interfaceid\":\"$IFID\",\"name\":\"Warteschlange\",\"key_\":\"uebung.warteschlange\",\"type\":0,\"value_type\":3,\"delay\":\"2s\"}" >/dev/null
TR=$(api trigger.create '{"description":"Warteschlange zu lang","expression":"last(/lin01/uebung.warteschlange)>100","priority":3}' | jq -r '.triggerids[0]')
api action.create "{\"name\":\"Probleme melden\",\"eventsource\":0,\"status\":0,\"esc_period\":\"1m\",\"filter\":{\"evaltype\":0,\"conditions\":[{\"conditiontype\":4,\"operator\":5,\"value\":\"3\"}]},\"operations\":[{\"operationtype\":0,\"esc_period\":\"0\",\"esc_step_from\":1,\"esc_step_to\":1,\"opmessage\":{\"default_msg\":0,\"mediatypeid\":\"$MT\",\"subject\":\"PROBLEM: {EVENT.NAME}\",\"message\":\"Host {HOST.NAME}\"},\"opmessage_usr\":[{\"userid\":\"1\"}]}],\"recovery_operations\":[{\"operationtype\":0,\"opmessage\":{\"default_msg\":0,\"mediatypeid\":\"$MT\",\"subject\":\"OK: {EVENT.NAME}\",\"message\":\"Host {HOST.NAME}\"},\"opmessage_usr\":[{\"userid\":\"1\"}]}]}" >/dev/null
api action.get '{"filter":{"name":"Probleme melden"},"output":["name","eventsource","status"],"selectFilter":"extend","selectOperations":["operationid"],"selectRecoveryOperations":["operationid"]}' | jq -r '.[0]|"Aktion \(.name): Quelle \(.eventsource) (0 = Trigger), Bedingung Schweregrad >= \(.filter.conditions[0].value), \(.operations|length) Operation, \(.recovery_operations|length) Wiederherstellungsoperation"'
alerts() { sql "select status from alerts where mediatypeid=$MT order by alertid" | tr '\n' ' '; }
sent() { wc -l < "$W/meldungen.log" | tr -d ' '; }
step "3. Problem löst Benachrichtigung aus, Wiederherstellung ebenfalls"
sleep 5; echo 150 > "$W/queue.txt"; wait_trig $TR 1
for _ in $(seq 1 90); do [ "$(sent)" -ge 1 ] && break; sleep 1; done
echo "Meldungen im Skript-Protokoll: $(sent)"; sed 's/^/  /' "$W/meldungen.log"
echo 20 > "$W/queue.txt"; wait_trig $TR 0
for _ in $(seq 1 90); do [ "$(sent)" -ge 2 ] && break; sleep 1; done
echo "Meldungen nach der Wiederherstellung: $(sent)"; sed -n 2p "$W/meldungen.log" | sed 's/^/  /'
for _ in $(seq 1 60); do [ "$(alerts)" = "1 1 " ] && break; sleep 1; done
echo "Tabelle alerts (Status 1 = gesendet): $(alerts)"
step "4. Wartungsfenster (mit Datensammlung): Problem entsteht, wird unterdrückt, keine Meldung; nach Löschen des Fensters kommt sie"
NOW=$(date +%s)
MID=$(api maintenance.create "{\"name\":\"Wartung lin01\",\"active_since\":$((NOW-300)),\"active_till\":$((NOW+3600)),\"maintenance_type\":0,\"hosts\":[{\"hostid\":\"$HID\"}],\"timeperiods\":[{\"timeperiod_type\":0,\"period\":3600,\"start_date\":$((NOW-300))}]}" | jq -r '.maintenanceids[0]')
for _ in $(seq 1 100); do [ "$(sql "select maintenance_status from hosts where hostid=$HID")" = 1 ] && break; sleep 1; done
echo "Host im Wartungsmodus (maintenance_status = 1): $(sql "select maintenance_status from hosts where hostid=$HID")"
BEFORE=$(sent); echo 150 > "$W/queue.txt"; wait_trig $TR 1; sleep 8
echo "Problem unterdrückt: $(api problem.get '{"output":["name","suppressed"]}' | jq -r '.[0]|"\(.name), suppressed=\(.suppressed)"')"
echo "Neue Meldungen während der Wartung: $(( $(sent) - BEFORE ))"
api maintenance.delete "[\"$MID\"]" >/dev/null
for _ in $(seq 1 100); do [ "$(api problem.get '{"output":["suppressed"]}' | jq -r '.[0].suppressed')" = 0 ] && break; sleep 1; done
for _ in $(seq 1 60); do [ "$(( $(sent) - BEFORE ))" -ge 1 ] && break; sleep 1; done
echo "Nach dem Löschen des Fensters: suppressed=$(api problem.get '{"output":["suppressed"]}' | jq -r '.[0].suppressed'), neue Meldungen: $(( $(sent) - BEFORE ))"
step "5. Fehlerbild: Medientyp mit nicht vorhandenem Skript"
MT2=$(api mediatype.create '{"name":"Kaputtes Skript","type":1,"status":0,"exec_path":"gibts-nicht.sh","parameters":[{"sortorder":"0","value":"{ALERT.SENDTO}"}]}' | jq -r '.mediatypeids[0]')
api user.update "{\"userid\":\"1\",\"medias\":[{\"mediatypeid\":\"$MT2\",\"sendto\":[\"x\"],\"active\":0,\"severity\":63,\"period\":\"1-7,00:00-24:00\"}]}" >/dev/null
api action.update "{\"actionid\":\"$(api action.get '{"filter":{"name":"Probleme melden"},"output":["actionid"]}' | jq -r '.[0].actionid')\",\"operations\":[{\"operationtype\":0,\"esc_period\":\"0\",\"esc_step_from\":1,\"esc_step_to\":1,\"opmessage\":{\"default_msg\":0,\"mediatypeid\":\"$MT2\",\"subject\":\"x\",\"message\":\"x\"},\"opmessage_usr\":[{\"userid\":\"1\"}]}]}" >/dev/null
echo 20 > "$W/queue.txt"; wait_trig $TR 0; sleep 6; echo 150 > "$W/queue.txt"; wait_trig $TR 1
for _ in $(seq 1 60); do [ -n "$(sql "select error from alerts where mediatypeid=$MT2 and status=2 limit 1")" ] && break; sleep 1; done
echo "Fehlgeschlagene Meldung (status 2): $(sql "select error from alerts where mediatypeid=$MT2 and status=2 limit 1" | sed -E 's#/tmp/p17#…#' | cut -c1-120)"
step "6. Dashboard über die API anlegen (nur Anlage geprüft, die Darstellung im Browser nicht)"
api dashboard.create '{"name":"Uebung Betrieb","display_period":30,"auto_start":1,"pages":[{"widgets":[{"type":"problems","name":"Aktuelle Probleme","x":0,"y":0,"width":12,"height":5},{"type":"clock","name":"Uhr","x":12,"y":0,"width":6,"height":5}]}]}' | jq -r '"Dashboard angelegt: ID vorhanden = \(.dashboardids|length>0)"'
api dashboard.get '{"filter":{"name":"Uebung Betrieb"},"output":["name"],"selectPages":["widgets"]}' | jq -r '.[0]|"Dashboard \(.name): Widgets \(.pages[0].widgets|map(.type)|join(", "))"'
echo "Fehlerbild: Widget außerhalb des Rasters (Breite 100):"; api dashboard.create '{"name":"Kaputt","pages":[{"widgets":[{"type":"clock","x":0,"y":0,"width":100,"height":3}]}]}' 2>&1 | cut -c1-160 | sed 's/^/  /'
