#!/usr/bin/env bash
# Modul 4: Ereignisweiterleitung (Windows Event Forwarding): Abonnement als XML-Datei prüfen. KEIN Windows und kein wecutil im Test; Aufbau nach dem Beispiel der Microsoft-Dokumentation zu wecutil (Suchauszug und Seite gelesen).
. "$(dirname "$0")/../lab.sh"
lab_up; D="$(dirname "$0")/.."
cat > "$W/abo.xml" <<'X'
<Subscription xmlns="http://schemas.microsoft.com/2006/03/windows/events/subscription">
    <SubscriptionId>Beispiel-Anmeldefehler</SubscriptionId>
    <SubscriptionType>SourceInitiated</SubscriptionType>
    <Description>Erfundenes Beispiel: fehlgeschlagene Anmeldungen weiterleiten</Description>
    <Enabled>true</Enabled>
    <Uri>http://schemas.microsoft.com/wbem/wsman/1/windows/EventLog</Uri>
    <ConfigurationMode>Custom</ConfigurationMode>
    <Delivery Mode="Push">
        <Batching>
            <MaxItems>5</MaxItems>
            <MaxLatencyTime>30000</MaxLatencyTime>
        </Batching>
        <PushSettings>
            <Heartbeat Interval="60000"/>
        </PushSettings>
    </Delivery>
    <Query>
        <![CDATA[
            <QueryList>
                <Query Path="Security">
                    <Select Path="Security">*[System[(EventID=4625)]]</Select>
                </Query>
            </QueryList>
        ]]>
    </Query>
    <ReadExistingEvents>false</ReadExistingEvents>
    <TransportName>http</TransportName>
    <ContentFormat>RenderedText</ContentFormat>
    <Locale Language="de-DE"/>
    <LogFile>ForwardedEvents</LogFile>
    <AllowedSourceNonDomainComputers></AllowedSourceNonDomainComputers>
    <AllowedSourceDomainComputers>O:NSG:NSD:(A;;GA;;;DC)(A;;GA;;;NS)</AllowedSourceDomainComputers>
</Subscription>
X
step "1. Wohlgeformtheit (xmllint) und Wurzel"
xmllint --noout "$W/abo.xml" && echo "wohlgeformt"; xmllint --xpath 'local-name(/*)' "$W/abo.xml"; echo
cat > "$W/pruefe.py" <<'PY'
import sys; sys.path.insert(0, sys.argv[2])
from lxml import etree
from evlib import abfrage
ns = {'s': 'http://schemas.microsoft.com/2006/03/windows/events/subscription'}
r = etree.parse(sys.argv[1]).getroot(); g = lambda p: (r.xpath(p, namespaces=ns) or [None])[0]
text = lambda p: (g(p).text or '').strip() if g(p) is not None else ''; typ = text('s:SubscriptionType')
print('Typ:', typ, '| Id:', text('s:SubscriptionId'), '| Protokoll:', text('s:TransportName'), '| Zielprotokoll:', text('s:LogFile'))
fehler = []
for pflicht in ('SubscriptionId', 'SubscriptionType', 'Uri', 'Query', 'LogFile'):
    if g('s:' + pflicht) is None: fehler.append('Element fehlt: ' + pflicht)
if typ not in ('SourceInitiated', 'CollectorInitiated'): fehler.append('unbekannter Typ')
quellen = g('s:EventSources')
if typ == 'CollectorInitiated' and quellen is None: fehler.append('CollectorInitiated braucht EventSources')
if typ == 'SourceInitiated' and quellen is not None: fehler.append('SourceInitiated hat keine EventSources')
q = etree.fromstring(text('s:Query').encode()); sel = q.xpath('//Select')[0]
print('Abfrage: Kanal %s, Ausdruck %s' % (sel.get('Path'), sel.text))
print('Prüfung:', 'ok' if not fehler else '%d Fehler' % len(fehler))
for f in fehler: print('  -', f)
if len(sys.argv) > 3: print('Treffer im Beispielbestand:', len(abfrage(sel.text, sys.argv[3])))
PY
step "2. Aufbau prüfen und die Abfrage gegen die Beispielereignisse laufen lassen"
python3 "$W/pruefe.py" "$W/abo.xml" "$D" "$W/events.xml"
step "3. Fehlerfall: Quellenliste bei einem SourceInitiated-Abonnement"
sed 's|</Description>|</Description><EventSources/>|' "$W/abo.xml" > "$W/abo2.xml"; python3 "$W/pruefe.py" "$W/abo2.xml" "$D" | tail -3
step "4. Einrichtung (Text; Befehle laut Microsoft-Dokumentation, nicht ausgeführt)"
cat <<'T'
Quelle   : winrm qc -q ;  Gruppenrichtlinie SubscriptionManager (Computer Configuration > Administrative Templates > Windows Components > Event Forwarding) ;  gpupdate /force
Sammler  : winrm qc -q ;  wecutil qc /q ;  wecutil cs abo.xml
Prüfung  : wecutil gr Beispiel-Anmeldefehler ;  wecutil gs Beispiel-Anmeldefehler ;  Protokoll ForwardedEvents lesen
Sicherheitsprotokoll weiterleiten: das Konto NETWORK SERVICE in die Gruppe Event Log Readers aufnehmen
T
step "5. Zwei Arten (Dokumentation)"
echo "Collector-initiated: das Abonnement listet alle Quellen. Source-initiated: Quellen melden sich selbst (per Gruppenrichtlinie); Zugriff je Abonnement über SDDL-Liste (hier der Standard für Domänencomputer)."
