#!/usr/bin/env bash
# Modul 5: Elastic Stack im Überblick. MODELL in Python (Elasticsearch, Logstash, Beats und Kibana laufen hier NICHT); Gegenprobe der Zahlen mit jq.
. "$(dirname "$0")/../lab.sh"
lab_up; export PYTHONPATH="$HERE" W
python3 "$HERE/gen_logs.py" "$W/logs.jsonl" >/dev/null
cat > "$W/q.py" <<'PY'
import json, sys, os, esmodell
M = {"zeit": "date", "host": "keyword", "programm": "keyword", "level": "long", "facility": "keyword", "nachricht": "text", "ip": "keyword", "status": "long", "dauer_ms": "long", "aktion": "keyword", "port": "long", "benutzer": "keyword", "ereignis": "keyword", "methode": "keyword", "pfad": "keyword", "bytes": "long", "quelle": "keyword", "ziel": "keyword"}
ix = esmodell.Index(M)
for l in open(os.environ["W"] + "/logs.jsonl"): ix.add(json.loads(l))
def frage(titel, body, size=0):
    r = ix.suche(body, size); print(f"  {titel}\n    Abfrage: {json.dumps(body, ensure_ascii=False, separators=(',', ':'))}\n    Treffer: {r['gesamt']}")
    for t in r["treffer"]: print("    Beispiel:", t["nachricht"])
    for n, a in r.get("aggs", {}).items(): print(f"    Aggregation {n}: {json.dumps(a, ensure_ascii=False, separators=(',', ':'))}")
    return r
PY
step "1. Index mit Zuordnung (Mapping): Feldtypen keyword (exakt), text (zerlegt), long (Zahl), date"
python3 - <<'PY'
import os
exec(open(os.environ["W"] + "/q.py").read())
print(f"  Dokumente im Index: {len(ix.docs)}"); print("  Typen:", ", ".join(f"{k}={v}" for k, v in list(M.items())[:7]), "…")
PY
step "2. Abfragen: match (Text), term (exakt), range (Bereich), bool (Kombination)"
python3 - <<'PY'
import os
exec(open(os.environ["W"] + "/q.py").read())
frage("Volltext: Wörter 'failed password' (ODER-Verknüpfung der Wörter)", {"query": {"match": {"nachricht": "failed password"}}}, 1)
frage("Volltext mit UND", {"query": {"match": {"nachricht": {"query": "failed password", "operator": "and"}}}})
frage("Exakt: programm = sshd", {"query": {"term": {"programm": "sshd"}}})
frage("Fehlerbild: term auf einem Textfeld mit Großbuchstaben findet nichts", {"query": {"term": {"nachricht": "Failed"}}})
frage("Dasselbe mit kleinem Wort (so steht es im Index)", {"query": {"term": {"nachricht": "failed"}}})
frage("Bereich: status >= 500", {"query": {"range": {"status": {"gte": 500}}}})
frage("Kombination: nginx, Status >= 500, zwischen 16:30 und 16:40", {"query": {"bool": {"filter": [{"term": {"programm": "nginx"}}, {"range": {"status": {"gte": 500}}}, {"range": {"zeit": {"gte": "2026-10-26T16:30:00+01:00", "lte": "2026-10-26T16:40:00+01:00"}}}]}}})
PY
step "3. Aggregationen: Häufigkeiten, Mittelwert, Stundenverlauf"
python3 - <<'PY'
import os
exec(open(os.environ["W"] + "/q.py").read())
frage("Rechner nach Anzahl", {"size": 0, "aggs": {"je_host": {"terms": {"field": "host"}}}})
frage("Quellen der fehlgeschlagenen Anmeldungen (Top 3)", {"query": {"term": {"ereignis": "anmeldung_fehler"}}, "aggs": {"top_ip": {"terms": {"field": "ip", "size": 3}}}})
frage("Mittlere Antwortzeit aller Webanfragen (Millisekunden)", {"query": {"term": {"programm": "nginx"}}, "aggs": {"mittel_ms": {"avg": {"field": "dauer_ms"}}}})
frage("Fehler 500 je Stunde (nur Stunden mit Treffern)", {"query": {"term": {"status": 500}}, "aggs": {"je_stunde": {"date_histogram": {"field": "zeit", "fixed_interval": "1h"}}}})
PY
step "4. Gegenprobe mit jq (unabhängig vom Modell)"
echo "  Status >= 500:          $(jq -s '[.[]|select(.status!=null and .status>=500)]|length' "$W/logs.jsonl")"
echo "  sshd-Fehlschläge:       $(jq -s '[.[]|select(.ereignis=="anmeldung_fehler")]|length' "$W/logs.jsonl")"
echo "  Top-IP der Fehlschläge: $(jq -s '[.[]|select(.ereignis=="anmeldung_fehler")|.ip]|group_by(.)|map({ip:.[0],n:length})|sort_by(-.n)|.[0]|"\(.ip) (\(.n))"' -r "$W/logs.jsonl")"
step "5. Bausteine des Elastic Stack und Beispielkonfigurationen (NICHT ausgeführt; Schreibweise aus Fachwissen, nicht bestätigt)"
cat <<'T'
  Beats (leichte Sammler auf den Rechnern) -> Logstash (Aufbereitung, optional) -> Elasticsearch (Index und Suche) -> Kibana (Oberfläche).
  Lizenzmodell und Versionsstand ändern sich; vor einem Einsatz mit Datum auf der Herstellerseite prüfen (hier nicht geprüft).
  Beispiel (Filebeat, YAML):            filebeat.inputs: [{type: filestream, id: web, paths: [/var/log/nginx/access.log]}]
  Beispiel (Logstash-Pipeline):         input { beats { port => 5044 } }  filter { grok { match => { "message" => "%{COMBINEDAPACHELOG}" } } }  output { elasticsearch { hosts => ["http://127.0.0.1:9200"] } }
T
