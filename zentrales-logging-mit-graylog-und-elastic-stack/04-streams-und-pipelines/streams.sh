#!/usr/bin/env bash
# Modul 4: Streams und Pipelines. MODELL in Python (nicht Graylog): Regeln als JSON, angewendet auf erfundene Logdaten (gen_logs.py).
. "$(dirname "$0")/../lab.sh"
lab_up; export PYTHONPATH="$HERE"
python3 "$HERE/gen_logs.py" "$W/logs.jsonl" >/dev/null
step "1. Streams als Regeldatei: Sicherheit, Web-Fehler (Fehler 500 und höher), Firewall-Verweigerungen"
cat > "$W/streams.json" <<'J'
[
 {"name": "Sicherheit",   "match": "any", "rules": [{"field": "programm", "op": "equals", "value": "sshd"}, {"field": "nachricht", "op": "contains", "value": "DENY"}]},
 {"name": "Web-Fehler",   "match": "all", "rules": [{"field": "programm", "op": "equals", "value": "nginx"}, {"field": "nachricht", "op": "regex", "value": " 5\\d\\d \\d+ "}]},
 {"name": "Firewall-Aus", "match": "all", "remove_from_default": true, "rules": [{"field": "programm", "op": "equals", "value": "firewall"}, {"field": "nachricht", "op": "contains", "value": "DENY", "invert": true}]}
]
J
jq -r '.[]|"  \(.name): \(.match), \(.rules|length) Regeln\(if .remove_from_default then ", aus Default entfernt" else "" end)"' "$W/streams.json"
step "2. Nachrichten auf die Streams verteilen (rohe Nachrichten: nur zeit, host, programm, level, nachricht)"
python3 - "$W/logs.jsonl" "$W/streams.json" <<'PY'
import json, sys, collections, pipeline
streams = json.load(open(sys.argv[2])); z = collections.Counter(); gesamt = 0; mehrfach = 0
for l in open(sys.argv[1]):
    e = json.loads(l); n = {k: e[k] for k in ("zeit", "host", "programm", "level", "nachricht")}; gesamt += 1
    s = pipeline.streams_zuordnen(streams, n); z.update(s); mehrfach += len(s) > 1 and "Default" not in s[:1]
print(f"  Nachrichten gesamt: {gesamt}")
for k in ("Sicherheit", "Web-Fehler", "Firewall-Aus", "Default"): print(f"  Stream {k:13s}: {z[k]}")
print(f"  Summe der Stream-Zuordnungen: {sum(z.values())} (eine Nachricht kann in mehreren Streams liegen)")
PY
step "3. Pipeline: Stufe 0 zerlegt den Text in Felder, Stufe 1 klassifiziert und leitet um, Stufe 2 verwirft Rauschen"
cat > "$W/pipeline.json" <<'J'
{"name": "Standard", "stages": [
 {"stage": 0, "weiter": "either", "rules": [
   {"name": "ssh-felder", "when": [{"field": "programm", "op": "equals", "value": "sshd"}],
    "then": [{"do": "extract", "field": "nachricht", "regex": "(?P<ergebnis>Failed|Accepted) password for (?P<benutzer>\\w+) from (?P<ip>[0-9.]+)"}]},
   {"name": "nginx-felder", "when": [{"field": "programm", "op": "equals", "value": "nginx"}],
    "then": [{"do": "extract", "field": "nachricht", "regex": "^(?P<ip>[0-9.]+) \\w+ (?P<pfad>\\S+) (?P<status>\\d{3}) (?P<bytes>\\d+) (?P<dauer_ms>\\d+)ms"}]}]},
 {"stage": 1, "weiter": "either", "rules": [
   {"name": "ssh-fehlschlag", "when": [{"field": "ergebnis", "op": "equals", "value": "Failed"}],
    "then": [{"do": "set_field", "field": "ereignis", "value": "anmeldung_fehler"}, {"do": "route", "stream": "Sicherheit"}]},
   {"name": "web-500", "when": [{"field": "status", "op": "greater", "value": "499"}],
    "then": [{"do": "set_field", "field": "ereignis", "value": "serverfehler"}, {"do": "route", "stream": "Web-Fehler"}]}]},
 {"stage": 2, "weiter": "either", "rules": [
   {"name": "rauschen-verwerfen", "when": [{"field": "programm", "op": "equals", "value": "firewall"}, {"field": "nachricht", "op": "contains", "value": "ALLOW tcp"}, {"field": "nachricht", "op": "contains", "value": ":53"}],
    "then": [{"do": "drop"}]}]}
]}
J
python3 - "$W/logs.jsonl" "$W/pipeline.json" <<'PY'
import json, sys, collections, pipeline
pl = json.load(open(sys.argv[2])); prot = {}; gesamt = verworfen = 0; streams = collections.Counter(); bsp = None
for l in open(sys.argv[1]):
    e = json.loads(l); n = {k: e[k] for k in ("zeit", "host", "programm", "level", "nachricht")}; gesamt += 1
    pipeline.pipeline(pl, n, prot)
    if n.get("_verworfen"): verworfen += 1; continue
    streams.update(n.get("_streams", []))
    if bsp is None and n.get("ereignis") == "anmeldung_fehler": bsp = n
print(f"  Nachrichten rein: {gesamt}, verworfen: {verworfen}, weiter: {gesamt - verworfen}")
for k in sorted(prot): print(f"  Regel {k:20s} Treffer: {prot[k]}")
print(f"  Umgeleitet: " + ", ".join(f"{k}={v}" for k, v in sorted(streams.items())))
print("  Beispiel nach der Pipeline:", {k: bsp[k] for k in ("host", "benutzer", "ip", "ereignis", "_streams")})
PY
step "4. Reihenfolge zählt: dieselbe Klassifizierungsregel in Stufe 0 (vor der Zerlegung) findet das Feld noch nicht"
python3 - "$W/logs.jsonl" "$W/pipeline.json" <<'PY'
import json, sys, copy, pipeline
pl = json.load(open(sys.argv[2])); falsch = copy.deepcopy(pl)
falsch["stages"][0]["rules"].insert(0, falsch["stages"][1]["rules"][0]); falsch["stages"][1]["rules"].pop(0)   # Klassifizierung an den Anfang von Stufe 0 verschieben, vor die Zerlegung
def zaehle(p):
    c = 0
    for l in open(sys.argv[1]):
        e = json.loads(l); n = {k: e[k] for k in ("zeit", "host", "programm", "level", "nachricht")}; pipeline.pipeline(p, n)
        c += n.get("ereignis") == "anmeldung_fehler"
    return c
print(f"  Richtige Reihenfolge: {zaehle(pl)} Anmeldefehler erkannt; Klassifizierung vor der Zerlegung: {zaehle(falsch)}")
PY
step "5. Dieselbe Regel in der Regelsprache von Graylog (NICHT ausgeführt; Schreibweise aus Fachwissen, nicht bestätigt)"
cat <<'T'
  rule "ssh-fehlschlag"
  when has_field("ergebnis") && to_string($message.ergebnis) == "Failed"
  then
    set_field("ereignis", "anmeldung_fehler");
    route_to_stream("Sicherheit");
  end
T
