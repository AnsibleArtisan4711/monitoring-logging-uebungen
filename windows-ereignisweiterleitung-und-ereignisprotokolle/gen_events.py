#!/usr/bin/env python3
"""Erzeugt erfundene Beispielereignisse im Aufbau von Windows-Ereignissen (XML) in eine Datei. Feste Zufallsfolge, keine echten Daten.
Aufruf: gen_events.py AUSGABE.xml"""
import sys, random
from xml.sax.saxutils import escape
random.seed(66)
NS = 'http://schemas.microsoft.com/win/2004/08/events/event'
hosts = ['pc01.example.org', 'pc02.example.org', 'srv01.example.org']
users = ['anna', 'ben', 'cara']
ev = []; rec = {h: 0 for h in hosts}
def add(zeit, host, kanal, prov, eid, level, daten):
    rec[host] += 1
    d = ''.join('<Data Name="%s">%s</Data>' % (k, escape(str(v))) for k, v in daten.items())
    ev.append((zeit, '<Event xmlns="%s"><System><Provider Name="%s"/><EventID>%d</EventID><Level>%d</Level><TimeCreated SystemTime="%s"/><EventRecordID>%d</EventRecordID><Channel>%s</Channel><Computer>%s</Computer></System><EventData>%s</EventData></Event>' % (NS, prov, eid, level, zeit, rec[host], kanal, host, d)))
SEC = 'Microsoft-Windows-Security-Auditing'
def t(h, m, s=0): return '2026-12-01T%02d:%02d:%02d.000Z' % (h, m, s)
# normale Anmeldungen
for i in range(12):
    h = random.choice(hosts[:2]); u = random.choice(users)
    add(t(8 + i // 4, (i * 7) % 60), h, 'Security', SEC, 4624, 0, {'TargetUserName': u, 'LogonType': 2, 'IpAddress': '-'})
    add(t(8 + i // 4, (i * 7) % 60, 30), h, 'Security', SEC, 4634, 0, {'TargetUserName': u, 'LogonType': 2})
# einzelne Tippfehler
for u, mi in (('anna', 20), ('ben', 41)): add(t(9, mi), 'pc01.example.org', 'Security', SEC, 4625, 0, {'TargetUserName': u, 'LogonType': 2, 'IpAddress': '-', 'Status': '0xC000006D'})
# Serie fehlgeschlagener Netzwerk-Anmeldungen von einer Adresse, danach Sperre
for i in range(8): add(t(10, 5, i * 5), 'srv01.example.org', 'Security', SEC, 4625, 0, {'TargetUserName': 'cara', 'LogonType': 3, 'IpAddress': '10.66.0.99', 'Status': '0xC000006D'})
add(t(10, 5, 50), 'srv01.example.org', 'Security', SEC, 4740, 0, {'TargetUserName': 'cara', 'CallerComputerName': 'pc02'})
# Verwaltung
add(t(11, 0), 'srv01.example.org', 'Security', SEC, 4720, 0, {'TargetUserName': 'dora', 'SubjectUserName': 'admin1'})
add(t(11, 2), 'srv01.example.org', 'System', 'Service Control Manager', 7045, 4, {'ServiceName': 'BeispielDienst', 'ImagePath': 'C:\\Beispiel\\dienst.exe'})
add(t(11, 30), 'pc02.example.org', 'Security', 'Microsoft-Windows-Eventlog', 1102, 4, {'SubjectUserName': 'admin1'})
# Rauschen
for i in range(30): add(t(8 + i // 6, (i * 11) % 60), random.choice(hosts), 'Application', 'BeispielAnwendung', 1000 + i % 3, 4, {'Meldung': 'Hintergrundaufgabe %d' % i})
for i in range(10): add(t(8 + i // 3, (i * 13) % 60, 15), random.choice(hosts), 'System', 'Microsoft-Windows-Time-Service', 37, 3, {'Quelle': 'zeit.example.org'})
ev.sort(key=lambda x: x[0])
open(sys.argv[1], 'w', encoding='utf-8').write('<Events>\n' + '\n'.join(x[1] for x in ev) + '\n</Events>\n')
