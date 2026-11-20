"""Hilfsfunktionen: erfundene Ereignisse (XML im Windows-Aufbau) laden."""
from lxml import etree
NS = {'e': 'http://schemas.microsoft.com/win/2004/08/events/event'}
def lade(pfad):
    return etree.parse(pfad).getroot().findall('e:Event', NS)
def feld(ev, name):
    r = ev.xpath('e:System/e:%s' % name, namespaces=NS); return r[0].text if r else None
def kanal(ev): return feld(ev, 'Channel')
def eid(ev): return int(feld(ev, 'EventID'))
def host(ev): return feld(ev, 'Computer')
def zeit(ev): return ev.xpath('e:System/e:TimeCreated/@SystemTime', namespaces=NS)[0]
def daten(ev): return {d.get('Name'): d.text for d in ev.xpath('e:EventData/e:Data', namespaces=NS)}

import re
_NAMEN = r'\b(System|EventID|Level|Channel|Computer|TimeCreated|Provider|EventData|Data)\b'
def abfrage(select, pfad):
    """Wertet den Inhalt eines <Select> (Form *[System[...]]) gegen eine Ereignisdatei aus. LERNMODELL: nicht das Windows-Verhalten."""
    xp = re.sub(r'(?<![@\w:])' + _NAMEN, r'e:\1', select)
    if xp.startswith('*['): xp = 'e:Event' + xp[1:]
    elif xp.startswith('Event['): xp = 'e:' + xp
    else: raise ValueError('nur Ausdrücke der Form *[...] oder Event[...] unterstützt')
    return etree.parse(pfad).getroot().xpath(xp, namespaces=NS)
