#!/usr/bin/env bash
# Modul 7 (Priorität 2): Warnungen aus Logdaten. Eine kleine Regelmaschine in Python spielt erfundene Logdaten nach Zeit ab (Fenster, Schwellen, Sperrzeit).
# Kein Graylog, kein Elasticsearch: die Regeln im Stil von „Ereignisdefinitionen“ sind ein Modell.
. "$(dirname "$0")/../lab.sh"
lab_up; L="$W/logs.jsonl"; python3 "$HERE/gen_logs.py" "$L" >/dev/null; export PYTHONPATH="$HERE"
cat > "$W/regeln.json" <<'J'
[
 {"name": "Passwortraten", "wo": {"ereignis": "anmeldung_fehler"}, "gruppe": "ip",     "art": "anzahl",     "schwelle": 10, "fenster_s": 60,  "sperre_s": 600, "schwere": "hoch"},
 {"name": "Fehlerwelle",   "wo": {"status_ab": 500},               "gruppe": "host",   "art": "anzahl",     "schwelle": 20, "fenster_s": 300, "sperre_s": 600, "schwere": "hoch"},
 {"name": "Portscan",      "wo": {"aktion": "deny"},               "gruppe": "quelle", "art": "verschieden:port", "schwelle": 10, "fenster_s": 120, "sperre_s": 600, "schwere": "mittel"}
]
J
cat > "$W/motor.py" <<'PY'
import json, sys, collections
from datetime import datetime
def passt(e, wo):
    for k, v in wo.items():
        if k == "status_ab":
            if e.get("status") is None or e["status"] < v: return False
        elif e.get(k) != v: return False
    return True
def abspielen(events, regeln, sperre=True):
    alarme = []; fenster = collections.defaultdict(collections.deque); letzter = {}
    for e in events:
        t = datetime.fromisoformat(e["zeit"]).timestamp()
        for r in regeln:
            if not passt(e, r["wo"]): continue
            key = (r["name"], e.get(r["gruppe"])); q = fenster[key]
            wert = e.get(r["art"].split(":")[1]) if ":" in r["art"] else None
            q.append((t, wert))
            while q and t - q[0][0] > r["fenster_s"]: q.popleft()
            n = len({w for _, w in q}) if ":" in r["art"] else len(q)
            if n >= r["schwelle"] and (not sperre or t - letzter.get(key, -1e18) >= r["sperre_s"]):
                letzter[key] = t; alarme.append({"zeit": e["zeit"][11:19], "regel": r["name"], "gruppe": key[1], "wert": n, "schwere": r["schwere"]})
    return alarme
PY
step "1. Regeln als Daten (Name, Bedingung, Gruppierung, Schwelle, Zeitfenster, Sperrzeit)"
jq -r '.[]|"  \(.name): \(.art) >= \(.schwelle) in \(.fenster_s) s je \(.gruppe), danach \(.sperre_s) s Sperrzeit, Schwere \(.schwere)"' "$W/regeln.json"
step "2. Abspielen der Tagesdaten: Alarme mit Sperrzeit"
python3 - "$L" "$W" <<'PY'
import json, sys; sys.path.insert(0, sys.argv[2]); import motor
ev = [json.loads(l) for l in open(sys.argv[1])]; reg = json.load(open(sys.argv[2] + "/regeln.json"))
a = motor.abspielen(ev, reg)
for x in a: print(f"  {x['zeit']}  {x['schwere']:6s} {x['regel']:14s} {x['gruppe']}  (Wert {x['wert']})")
print(f"  Alarme gesamt: {len(a)}")
PY
step "3. Ohne Sperrzeit: jede weitere Meldung innerhalb des Fensters löst erneut aus (Alarmflut)"
python3 - "$L" "$W" <<'PY'
import json, sys, collections; sys.path.insert(0, sys.argv[2]); import motor
ev = [json.loads(l) for l in open(sys.argv[1])]; reg = json.load(open(sys.argv[2] + "/regeln.json"))
mit = motor.abspielen(ev, reg); ohne = motor.abspielen(ev, reg, sperre=False)
print(f"  mit Sperrzeit: {len(mit)} Alarme; ohne Sperrzeit: {len(ohne)} Alarme")
for r, n in sorted(collections.Counter(x['regel'] for x in ohne).items()): print(f"    ohne Sperrzeit {r}: {n}")
PY
step "4. Fehlalarme prüfen: einzelne Tippfehler und normale Anmeldungen lösen nichts aus"
python3 - "$L" "$W" <<'PY'
import json, sys; sys.path.insert(0, sys.argv[2]); import motor
ev = [json.loads(l) for l in open(sys.argv[1])]; reg = json.load(open(sys.argv[2] + "/regeln.json"))
ohne99 = [e for e in ev if e.get("ip") != "10.18.0.99"]
a = [x for x in motor.abspielen(ohne99, reg) if x["regel"] == "Passwortraten"]
print(f"  Passwortraten ohne die Daten von 10.18.0.99: {len(a)} Alarme (erwartet 0)")
zu_niedrig = [dict(r, schwelle=2, fenster_s=3600) if r["name"] == "Passwortraten" else r for r in reg]
print(f"  Schwelle zu niedrig (2 Fehlschläge in 1 Stunde), wieder ohne 10.18.0.99: {len([x for x in motor.abspielen(ohne99, zu_niedrig) if x['regel'] == 'Passwortraten'])} Alarm(e) – Fehlalarme durch einfache Tippfehler")
PY
step "5. Stille erkennen: längste Lücke ohne Ereignis je Rechner (Hinweis auf ausgefallenen Sammler oder Rechner)"
python3 - "$L" <<'PY'
import json, sys, collections
from datetime import datetime
t = collections.defaultdict(list)
for l in open(sys.argv[1]):
    e = json.loads(l); t[e["host"]].append(datetime.fromisoformat(e["zeit"]))
for h in sorted(t):
    l = sorted(t[h]); g = max(((b - a).total_seconds(), a) for a, b in zip(l, l[1:]))
    print(f"  {h}: längste Lücke {g[0]/60:.1f} Minuten, beginnend um {g[1].time()}")
PY
step "6. Test der Regelmaschine mit eigenen kleinen Ereignissen (Selbsttest)"
python3 - "$W" <<'PY'
import sys, json; sys.path.insert(0, sys.argv[1]); import motor
reg = [{"name": "T", "wo": {"ereignis": "x"}, "gruppe": "ip", "art": "anzahl", "schwelle": 3, "fenster_s": 10, "sperre_s": 60, "schwere": "hoch"}]
def e(s, ip="a"): return {"zeit": f"2026-10-26T10:00:{s:02d}+01:00", "ereignis": "x", "ip": ip}
fall = {"2 in 10 s: kein Alarm": ([e(0), e(5)], 0), "3 in 10 s: ein Alarm": ([e(0), e(5), e(9)], 1), "3 in 20 s: kein Alarm": ([e(0), e(10), e(20)], 0),
        "3 von drei Adressen: kein Alarm": ([e(0, "a"), e(1, "b"), e(2, "c")], 0), "6 dicht beieinander: wegen Sperrzeit nur ein Alarm": ([e(i) for i in range(6)], 1)}
for n, (ev, soll) in fall.items(): ist = len(motor.abspielen(ev, reg)); print(f"  {'OK    ' if ist == soll else 'FEHLER'} {n} (ist {ist}, soll {soll})")
PY
step "7. Benachrichtigung im Graylog-Stil (NICHT ausgeführt; Begriffe aus Fachwissen, nicht bestätigt)"
cat <<'T'
  Eine „Ereignisdefinition“ besteht aus Bedingung (Suchanfrage, Schwelle, Zeitfenster), Gruppierung, Sperrzeit und Benachrichtigung (E-Mail, HTTP). Menünamen und Felder: nicht bestätigt.
T
