"""Lernmodell (KEIN PRTG): Sensorstatus, Benachrichtigung, Abhängigkeiten, Lizenzbudget. Alle Zeiten in Sekunden, simuliert."""
FREEWARE_LIMIT = 100          # Stand 20.11.2026 laut Handbuchseite "Available Licenses" (Freeware: bis 100 Sensoren); Stand prüfen
TRIAL_TAGE = 30               # ebenda: Test 30 Tage, danach Freeware

def status(wert, warn=None, fehler=None, ok=True):
    """Up/Warning/Down aus einem Messwert mit oberen Grenzen; ok=False (keine Antwort) ergibt Down."""
    if not ok: return "Down"
    if fehler is not None and wert > fehler: return "Down"
    if warn is not None and wert > warn: return "Warning"
    return "Up"

def sensoren_zaehlen(geraete):
    """geraete: {name: {vorlage: anzahl}} -> (je Gerät, gesamt)."""
    je = {g: sum(v.values()) for g, v in geraete.items()}
    return je, sum(je.values())

def lauf(messreihe, scan=60, down_nach=1):
    """Status je Intervall. messreihe: Liste von Status 'Up'/'Warning'/'Down'. down_nach: Fehlversuche, bevor 'Down' gilt
    (vorher 'Down (teilweise)'). Rückgabe: Liste (t, roh, gemeldet)."""
    aus, fehl = [], 0
    for i, s in enumerate(messreihe):
        fehl = fehl + 1 if s == "Down" else 0
        gem = s if s != "Down" else ("Down" if fehl >= down_nach else "Down (teilweise)")
        aus.append((i * scan, s, gem))
    return aus

def benachrichtigungen(ereignisse, ausloeser_s=60, wiederholung_s=0, eskalation_s=None, ende=None):
    """ereignisse: Liste (t, status) des gemeldeten Zustands je Sensor. Löst aus, wenn 'Down' länger als ausloeser_s dauert.
    wiederholung_s>0: erneut alle n Sekunden. eskalation_s: zusätzliche Stufe 2 nach n Sekunden Down. Rückgabe Liste (t, text)."""
    ausg, seit = [], None
    ev = list(ereignisse)
    for i, (t, s) in enumerate(ev):
        nxt = ev[i + 1][0] if i + 1 < len(ev) else (ende if ende is not None else t)
        if s == "Down":
            seit = t if seit is None else seit
            t1 = seit + ausloeser_s
            if t1 <= nxt and not any(x[1].startswith("Stufe 1") for x in ausg if x[0] >= seit):
                ausg.append((t1, "Stufe 1: Sensor ist Down"))
            if eskalation_s is not None and seit + eskalation_s <= nxt and not any(x[1].startswith("Stufe 2") for x in ausg if x[0] >= seit):
                ausg.append((seit + eskalation_s, "Stufe 2: weiter Down (Eskalation)"))
            if wiederholung_s:
                k = 1
                while t1 + k * wiederholung_s <= nxt:
                    z = t1 + k * wiederholung_s
                    if (z, "Wiederholung") not in ausg and z >= t: ausg.append((z, "Wiederholung"))
                    k += 1
        else:
            if seit is not None and any(x[1].startswith("Stufe 1") and x[0] >= seit for x in ausg):
                ausg.append((t, "Entwarnung: Sensor ist wieder " + s))
            seit = None
    return sorted(set(ausg))

def abhaengigkeit(baum, down):
    """baum: {knoten: eltern oder None}; down: Menge der wirklich ausgefallenen Knoten. Rückgabe (gemeldet_down, pausiert):
    Kinder eines ausgefallenen Vorfahren werden pausiert (nicht als Down gemeldet)."""
    def vorfahren(k):
        e = baum[k]
        while e is not None:
            yield e; e = baum[e]
    gem, pau = [], []
    for k in baum:
        if any(v in down for v in vorfahren(k)): pau.append(k)
        elif k in down: gem.append(k)
    return sorted(gem), sorted(pau)

def zyklus(baum):
    for k in baum:
        gesehen, e = {k}, baum[k]
        while e is not None:
            if e in gesehen: return True
            gesehen.add(e); e = baum.get(e)
    return False

def verfuegbarkeit(sek_gesamt, sek_down):
    return round(100.0 * (sek_gesamt - sek_down) / sek_gesamt, 3)
