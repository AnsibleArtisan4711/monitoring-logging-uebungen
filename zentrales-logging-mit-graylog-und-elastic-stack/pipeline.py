"""Modell für Streams und Pipelines im Stil von Graylog. Regeln stehen als Daten (JSON). NICHT Graylog: Regelsprache, Stufen und Verhalten sind Fachwissen und nicht gegen Graylog geprüft."""
import re

def bed(b, n):
    """Einzelne Bedingung auf eine Nachricht (dict) anwenden. op: equals, contains, regex, greater, present (invert: Ergebnis umkehren)."""
    w = n.get(b["field"]); op = b["op"]
    if op == "present": r = w is not None
    elif w is None: r = False
    elif op == "equals": r = str(w) == str(b["value"])
    elif op == "contains": r = str(b["value"]) in str(w)
    elif op == "regex": r = re.search(b["value"], str(w)) is not None
    elif op == "greater": r = float(w) > float(b["value"])
    else: raise ValueError("unbekannte Operation " + op)
    return (not r) if b.get("invert") else r

def stream_passt(s, n):
    erg = [bed(b, n) for b in s["rules"]]
    return bool(erg) and (all(erg) if s.get("match", "all") == "all" else any(erg))

def streams_zuordnen(streams, n):
    """Liefert die Namen aller Streams, deren Regeln passen. 'Default' bleibt, wenn kein Stream die Nachricht aus dem Default-Stream entfernt."""
    ziel = [s["name"] for s in streams if stream_passt(s, n)]
    entfernt = any(s.get("remove_from_default") for s in streams if s["name"] in ziel)
    return ziel + ([] if entfernt else ["Default"])

def aktion(a, n):
    t = a["do"]
    if t == "set_field": n[a["field"]] = a["value"]
    elif t == "remove_field": n.pop(a["field"], None)
    elif t == "lowercase": n[a["field"]] = str(n.get(a["field"], "")).lower()
    elif t == "extract":     # benannte Gruppen eines regulären Ausdrucks werden zu Feldern
        m = re.search(a["regex"], str(n.get(a["field"], "")))
        if m:
            for k, v in m.groupdict().items(): n[k] = v
    elif t == "route": n.setdefault("_streams", []).append(a["stream"])
    elif t == "drop": n["_verworfen"] = True
    else: raise ValueError("unbekannte Aktion " + t)

def pipeline(pl, n, protokoll=None):
    """Stufen in aufsteigender Reihenfolge; innerhalb einer Stufe laufen alle Regeln. Eine Stufe lässt die Nachricht weiter, wenn 'weiter' erfüllt ist (all/either)."""
    for st in sorted(pl["stages"], key=lambda s: s["stage"]):
        treffer = 0
        for r in st["rules"]:
            if all(bed(b, n) for b in r["when"]):
                treffer += 1
                if protokoll is not None: protokoll.setdefault(r["name"], 0); protokoll[r["name"]] += 1
                for a in r["then"]: aktion(a, n)
                if n.get("_verworfen"): return n
        if st.get("weiter", "either") == "all" and treffer < len(st["rules"]): break
        if st.get("weiter", "either") == "either" and treffer == 0 and st.get("weiter_pflicht"): break
    return n
