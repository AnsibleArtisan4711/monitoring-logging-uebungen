#!/usr/bin/env bash
# Modul 6: Suchen und Auswerten von Logdaten mit echten Werkzeugen (jq, sort, awk, Python) auf erfundenen Logdaten. Kein Graylog, kein Elasticsearch.
. "$(dirname "$0")/../lab.sh"
lab_up; L="$W/logs.jsonl"; python3 "$HERE/gen_logs.py" "$L" >/dev/null
step "1. Zählen: Ereignisse je Rechner und je Schweregrad (level)"
jq -r '.host' "$L" | sort | uniq -c | sort -rn | awk '{printf "  %-6s %5d\n",$2,$1}'
jq -r '.level' "$L" | sort -n | uniq -c | awk '{printf "  level %s: %d\n",$2,$1}'
step "2. Rangliste: Quelladressen der Firewall-Verweigerungen (Top 3)"
jq -r 'select(.aktion=="deny")|.quelle' "$L" | sort | uniq -c | sort -rn | head -3 | awk '{printf "  %-12s %3d\n",$2,$1}'
step "3. Verlauf: Ereignisse je Stunde als Balken (ein # = 25 Ereignisse) – Auffälligkeiten sichtbar machen"
jq -r '.zeit[11:13]' "$L" | sort | uniq -c | awk '{n=int($1/25); b=""; for(i=0;i<n;i++) b=b "#"; printf "  %s Uhr %4d %s\n",$2,$1,b}'
step "4. Portscan finden: Adressen, die in 2 Minuten mindestens 10 verschiedene Ziel-Ports ansprachen und verweigert wurden"
python3 - "$L" <<'PY'
import json, sys, collections
from datetime import datetime
ev = [json.loads(l) for l in open(sys.argv[1])]; deny = [e for e in ev if e.get("aktion") == "deny"]
d = collections.defaultdict(list)
for e in deny: d[e["quelle"]].append((datetime.fromisoformat(e["zeit"]), e["port"]))
for q, l in sorted(d.items()):
    l.sort(); best = 0
    for i, (t, _) in enumerate(l):
        ports = {p for (t2, p) in l[i:] if (t2 - t).total_seconds() <= 120}; best = max(best, len(ports))
    if best >= 10: print(f"  {q}: {best} verschiedene Ports innerhalb von 2 Minuten (erste Zeit {l[0][0].time()})")
print(f"  Adressen mit Verweigerungen insgesamt: {len(d)}")
PY
step "5. Passwortraten: fehlgeschlagene Anmeldungen je Minute und Quelle (ab 10 pro Minute) und was danach geschah"
python3 - "$L" <<'PY'
import json, sys, collections
ev = [json.loads(l) for l in open(sys.argv[1])]; c = collections.Counter(); 
for e in ev:
    if e.get("ereignis") == "anmeldung_fehler": c[(e["ip"], e["zeit"][:16])] += 1
for (ip, m), n in sorted(c.items()):
    if n >= 10:
        spaeter = [e for e in ev if e.get("ereignis") == "anmeldung_ok" and e["ip"] == ip and e["zeit"][:16] >= m]
        print(f"  {ip} um {m[11:]} Uhr: {n} Fehlschläge in der Minute; danach erfolgreiche Anmeldung von derselben Adresse: {'ja, ' + spaeter[0]['zeit'][11:19] + ' als ' + spaeter[0]['benutzer'] if spaeter else 'nein'}")
PY
step "6. Antwortzeiten: Median und 95. Perzentil je Stunde (nur Stunden mit p95 über 500 ms) und gesamt"
python3 - "$L" <<'PY'
import json, sys, statistics, collections
w = collections.defaultdict(list)
for l in open(sys.argv[1]):
    e = json.loads(l)
    if e.get("dauer_ms") is not None: w[e["zeit"][11:13]].append(e["dauer_ms"])
def p(x, q): x = sorted(x); return x[min(len(x) - 1, int(q * len(x)))]
alle = [v for l in w.values() for v in l]
print(f"  gesamt: n={len(alle)}, Median {statistics.median(alle):.0f} ms, p95 {p(alle, 0.95)} ms")
for h in sorted(w):
    if p(w[h], 0.95) > 500: print(f"  {h} Uhr: n={len(w[h])}, Median {statistics.median(w[h]):.0f} ms, p95 {p(w[h], 0.95)} ms")
PY
step "7. Fehlerquote je Stunde (Anteil HTTP-Status ≥ 500) in der auffälligen Stunde"
jq -r 'select(.status!=null)|[.zeit[11:13], (if .status>=500 then 1 else 0 end)]|@tsv' "$L" | awk '{n[$1]++; f[$1]+=$2} END{for(h in n) if (f[h]/n[h]>0.2) printf "  %s Uhr: %d von %d Anfragen = %.1f %%\n",h,f[h],n[h],100*f[h]/n[h]}' | sort
step "8. Fehlerbild: falscher Feldname liefert keine Fehlermeldung, nur leere Ergebnisse"
echo "  richtig  (.status >= 500): $(jq -s '[.[]|select(.status!=null and .status>=500)]|length' "$L") Treffer"
echo "  falsch   (.stauts >= 500): $(jq -s '[.[]|select(.stauts!=null and .stauts>=500)]|length' "$L") Treffer (kein Fehler, nur 0)"
echo "  Gegenprüfung: Feldnamen der Webereignisse: $(jq -r 'select(.programm=="nginx")|keys[]' "$L" | sort -u | tr '\n' ' ')"
