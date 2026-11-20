#!/usr/bin/env bash
# Modul 3: WMI, SNMP, SSH. Echt: snmpd (net-snmp 5.9.4) auf 127.0.0.1 mit snmpget/snmpwalk; SSH-ähnliche Befehle lokal. WMI braucht Windows und wurde NICHT ausgeführt.
. "$(dirname "$0")/../lab.sh"
lab_up
cat > "$W/snmpd.conf" <<CONF
agentaddress udp:127.0.0.1:$SNMPP
rocommunity uebung-lesen 127.0.0.1
sysName srv-snmp01
sysLocation Uebungsraum
sysContact it@example.org
CONF
snmpd -f -Lf "$W/snmpd.log" -C -c "$W/snmpd.conf" -p "$W/snmpd.pid" -I -ifTable,-ifXTable,-tcpTable,-udpTable,-ipAddressTable >/dev/null 2>&1 &
waitfor "snmpget -v2c -c uebung-lesen -t1 -r0 127.0.0.1:$SNMPP 1.3.6.1.2.1.1.5.0"
S="127.0.0.1:$SNMPP"
step "1. SNMP v2c lesen: Name, Ort, Kontakt (Community 'uebung-lesen' ist ein Übungswert)"
for o in 1.3.6.1.2.1.1.5.0 1.3.6.1.2.1.1.6.0 1.3.6.1.2.1.1.4.0; do cmd snmpget -v2c -c uebung-lesen -Oqv $S $o; done
step "2. Falsche Community: der Agent schweigt (Zeitüberschreitung); unbekannter Benutzer bei SNMP v3: sofortige Fehlermeldung"
cmd snmpget -v2c -c falsch -t1 -r0 -Oqv $S 1.3.6.1.2.1.1.5.0
cmd snmpget -v3 -l noAuthNoPriv -u gibtsnicht -t1 -r0 -Oqv $S 1.3.6.1.2.1.1.5.0
step "3. Eine OID, die es nicht gibt, und eine Tabelle laufen lassen (snmpwalk auf die Systemgruppe, Zeilenzahl)"
cmd snmpget -v2c -c uebung-lesen $S 1.3.6.1.2.1.99.9.9.0
echo "Zeilen der Systemgruppe: $(snmpwalk -v2c -c uebung-lesen -On $S 1.3.6.1.2.1.1 2>&1 | wc -l | tr -d ' ')"
step "4. Beschreibbar ist nicht nötig: ein Schreibversuch mit der Lese-Community scheitert"
cmd snmpset -v2c -c uebung-lesen -t1 -r0 $S 1.3.6.1.2.1.1.5.0 s neuername
step "5. Die Werte, die ein SNMP-Sensor liest: Speicher und Last aus dem Agenten (Namen statt Nummern mit -Os)"
snmpget -v2c -c uebung-lesen -Os $S UCD-SNMP-MIB::laLoadInt.1 2>&1 | sed -E 's/= INTEGER: [0-9]+/= INTEGER: <Last x100, schwankt>/'
snmpget -v2c -c uebung-lesen -Os $S HOST-RESOURCES-MIB::hrSystemProcesses.0 2>&1 | sed -E 's/= Gauge32: [0-9]+/= Gauge32: <Zahl der Prozesse, schwankt>/'
step "6. SSH-Sensor (Modell): PRTG führt Befehle auf dem Ziel aus; dieselben Befehle lokal, damit Sie die Ausgabe kennen"
echo '$ cat /proc/loadavg | awk "{print \$1}"  -> Zahl mit Dezimalpunkt:'; cat /proc/loadavg | awk '{print ($1 ~ /^[0-9]+\.[0-9]+$/) ? "ja" : "nein"}'
echo '$ df -P / | tail -1 | awk "{print \$5}"  -> endet auf %:'; df -P / | tail -1 | awk '{print ($5 ~ /%$/) ? "ja" : "nein"}'
step "7. WMI (nicht ausgeführt): was auf dem Windows-Ziel stimmen muss"
cat <<'TXT'
  - Konto mit Rechten für WMI/DCOM auf dem Ziel, Anmeldedaten im Gerät oder in der Gruppe hinterlegt
  - Namensauflösung vom PRTG-Server zum Ziel, RPC-Endpunktzuordnung (TCP 135) und dynamische RPC-Ports in der Firewall
  - Dienst "Windows-Verwaltungsinstrumentation" läuft; Test von der Probe aus mit PowerShell: Get-CimInstance Win32_OperatingSystem -ComputerName win01
  - Menünamen und Fehlertexte in PRTG: nicht bestätigt
TXT
