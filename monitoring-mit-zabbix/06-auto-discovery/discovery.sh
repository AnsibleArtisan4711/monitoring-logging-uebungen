#!/usr/bin/env bash
# Modul 6: Low-Level-Discovery (LLD): Entdeckungsregel, Item- und Trigger-Prototypen, Filter, verschwundene Ressourcen (echter Zabbix 7.0.32).
. "$(dirname "$0")/../lab.sh"
lab_up
mkdir -p "$W/queues"; echo 5 > "$W/queues/mail.txt"; echo 0 > "$W/queues/druck.txt"; echo 3 > "$W/queues/archiv.txt"
cat > "$W/disc.sh" <<'S'
#!/bin/bash
# gibt die Warteschlangen (Dateien in queues/) als LLD-JSON aus
d=$(dirname "$0")/queues; first=1; printf '{"data":['
for f in "$d"/*.txt; do [ -e "$f" ] || continue; n=$(basename "$f" .txt); [ $first = 1 ] || printf ','; first=0; printf '{"{#QUEUE}":"%s"}' "$n"; done; printf ']}'
S
chmod +x "$W/disc.sh"
printf 'UserParameter=uebung.queues.discovery,%s/disc.sh\nUserParameter=uebung.queue[*],cat %s/queues/$1.txt\n' "$W" "$W" > "$W/agent.d/uebung.conf"; restart_agent
step "1. Das Entdeckungsskript liefert JSON mit dem Makro {#QUEUE}; Prüfung mit jq"
J=$($ZBX/bin/zabbix_get -s 127.0.0.1 -p $AGP -k uebung.queues.discovery); echo "$J"
echo "$J" | jq -e '.data|length' >/dev/null && echo "gültiges JSON, $(echo "$J" | jq '.data|length') Einträge: $(echo "$J" | jq -r '[.data[]["{#QUEUE}"]]|join(", ")')"
printf 'Wert eines Elements (uebung.queue[mail]): '; $ZBX/bin/zabbix_get -s 127.0.0.1 -p $AGP -k 'uebung.queue[mail]'; echo
step "2. Host, Entdeckungsregel mit Filter (archiv ausschließen), Item- und Trigger-Prototyp"
GID=$(api hostgroup.create '{"name":"Uebung-Linux"}' | jq -r '.groupids[0]')
HID=$(api host.create "{\"host\":\"lin01\",\"groups\":[{\"groupid\":\"$GID\"}],\"macros\":[{\"macro\":\"{\$QUEUE_MAX}\",\"value\":\"100\"}],\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"127.0.0.1\",\"dns\":\"\",\"port\":\"$AGP\"}]}" | jq -r '.hostids[0]')
IFID=$(api host.get "{\"hostids\":\"$HID\",\"selectInterfaces\":[\"interfaceid\"]}" | jq -r '.[0].interfaces[0].interfaceid')
RID=$(api discoveryrule.create "{\"hostid\":\"$HID\",\"interfaceid\":\"$IFID\",\"name\":\"Warteschlangen entdecken\",\"key_\":\"uebung.queues.discovery\",\"type\":0,\"delay\":\"5s\",\"lifetime_type\":2,\"enabled_lifetime_type\":2,\"filter\":{\"evaltype\":0,\"conditions\":[{\"macro\":\"{#QUEUE}\",\"value\":\"^archiv\$\",\"operator\":9}]}}" | jq -r '.itemids[0]')
api itemprototype.create "{\"hostid\":\"$HID\",\"ruleid\":\"$RID\",\"interfaceid\":\"$IFID\",\"name\":\"Warteschlange {#QUEUE}\",\"key_\":\"uebung.queue[{#QUEUE}]\",\"type\":0,\"value_type\":3,\"delay\":\"3s\"}" >/dev/null
api triggerprototype.create '{"description":"Warteschlange {#QUEUE} über {$QUEUE_MAX}","expression":"last(/lin01/uebung.queue[{#QUEUE}])>{$QUEUE_MAX}","priority":3}' >/dev/null
api discoveryrule.get "{\"itemids\":\"$RID\",\"output\":[\"name\",\"key_\",\"delay\"],\"selectFilter\":\"extend\",\"selectItems\":\"count\"}" | jq -r '.[0]|"Regel: \(.name), Schlüssel \(.key_), Intervall \(.delay)\nFilter: \(.filter.conditions[0].macro) Operator \(.filter.conditions[0].operator) (9 = passt nicht auf) \(.filter.conditions[0].value)"'
echo "Prototypen: $(api itemprototype.get "{\"discoveryids\":\"$RID\",\"countOutput\":true}" | tr -d '"') Item-Prototyp, $(api triggerprototype.get "{\"discoveryids\":\"$RID\",\"countOutput\":true}" | tr -d '"') Trigger-Prototyp"
step "3. Entdeckung läuft: erzeugte Items und Trigger (archiv ist durch den Filter ausgeschlossen)"
lld_items() { api item.get "{\"hostids\":\"$HID\",\"output\":[\"key_\"],\"filter\":{\"flags\":4},\"sortfield\":\"key_\"}" | jq -r 'map(.key_)|join(", ")'; }
for _ in $(seq 1 60); do [ "$(api item.get "{\"hostids\":\"$HID\",\"filter\":{\"flags\":4},\"countOutput\":true}" | tr -d '"')" = 2 ] && break; sleep 1; done
echo "Entdeckte Items: $(lld_items)"
echo "Entdeckte Trigger: $(api trigger.get "{\"hostids\":\"$HID\",\"output\":[\"description\"],\"filter\":{\"flags\":4},\"expandDescription\":true,\"sortfield\":\"description\"}" | jq -r 'map(.description)|join("; ")')"
IM=$(itemid $HID 'uebung.queue[mail]'); printf 'Wert von uebung.queue[mail] = %s\n' "$(wait_val $IM)"
step "4. Neue Warteschlange erscheint (Datei anlegen), Trigger-Prototyp wirkt (Wert 150 bei Grenze 100)"
echo 8 > "$W/queues/scan.txt"; echo 150 > "$W/queues/mail.txt"
for _ in $(seq 1 60); do [ "$(api item.get "{\"hostids\":\"$HID\",\"filter\":{\"flags\":4},\"countOutput\":true}" | tr -d '"')" = 3 ] && break; sleep 1; done
echo "Entdeckte Items: $(lld_items)"
for _ in $(seq 1 90); do [ "$(api problem.get '{"countOutput":true}' | tr -d '"')" -ge 1 ] && break; sleep 1; done
echo "Problem: $(api problem.get '{"output":["name"]}' | jq -r 'map(.name)|join("; ")')"
step "5. Verschwundene Ressource: Datei druck.txt entfernen, Item wird sofort gelöscht (Einstellung „sofort löschen“)"
rm "$W/queues/druck.txt"
for _ in $(seq 1 60); do [ "$(api item.get "{\"hostids\":\"$HID\",\"filter\":{\"flags\":4},\"countOutput\":true}" | tr -d '"')" = 2 ] && break; sleep 1; done
echo "Entdeckte Items: $(lld_items)"
step "6. Fehlerbild: Skript liefert ungültiges JSON; die Regel wird nicht unterstützt"
printf '#!/bin/bash\necho "{data: kaputt"\n' > "$W/disc.sh"
for _ in $(seq 1 60); do [ -n "$(sql "select error from item_rtdata where itemid=$RID")" ] && break; sleep 1; done
echo "Fehler der Regel: $(sql "select error from item_rtdata where itemid=$RID" | cut -c1-110)"
echo "Bereits entdeckte Items bleiben bestehen: $(lld_items)"
