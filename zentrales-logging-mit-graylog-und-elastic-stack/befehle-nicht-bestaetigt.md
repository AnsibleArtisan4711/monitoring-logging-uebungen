# Befehle und Aussagen, die nicht bestätigt sind

Prüfliste für den ersten Durchlauf in den Hyper-V-VMs: Befund und Datum eintragen, danach den Hinweis in der Übung entfernen. Legende: **Q** = gegen Quelle gelesen; **L** = im Labor (Container) ausgeführt; **–** = weder noch.

| Modul | Befehl oder Aussage | Status | Nächster Schritt |
|---|---|---|---|
| alle | Aufbau des Hyper-V-Labors (privater Switch `Lab-Logging`, `log01`, `lin01`, `win01`) | – | laut Lehrplan aufbauen und prüfen |
| 01 | `rsyslogd -N1`, `rsyslog` (`imudp`, `mmjsonparse`, Vorlagen), `logger` (RFC 3164 und 5424) | echt im Container ausgeführt (`rsyslog` 8.2312); `journalctl` und Windows-Ereignisprotokoll **nicht ausgeführt** | auf `lin01` und `win01` mit dem installierten Stand wiederholen |
| 02 | `rsyslog` mit `omfwd` (UDP), Filter, `imfile`, Warteschlange (queue), falscher Zielport | echt im Container ausgeführt (zwei Instanzen auf `127.0.0.1`) | zwischen `lin01` und `log01` wiederholen, TCP und TLS zusätzlich prüfen |
| 03 | GELF 1.1 (JSON), gzip/zlib, Zerlegung großer Datagramme; Modell-Input in Python über UDP auf `127.0.0.1` | Datagramme und Komprimierung echt; **Graylog nicht ausgeführt** | GELF-Input in Graylog anlegen (Menüs nicht bestätigt) und Nachrichten senden |
| 04 | Streams und Pipeline-Stufen als Python-Modell; Regel in der Schreibweise von Graylog (Text) | Modell; **Graylog nicht ausgeführt**, Regelsprache nicht bestätigt | in Graylog nachbauen und Trefferzahlen vergleichen |
| 05 | Index, Mapping und Abfragen (`match`, `term`, `range`, `bool`, Aggregationen) als Python-Modell; Gegenprobe mit `jq`; Beispielkonfigurationen Filebeat/Logstash (Text) | Modell und `jq` echt; **Elasticsearch, Logstash, Beats nicht ausgeführt** | Elasticsearch oder OpenSearch installieren (Version und Lizenz mit Datum prüfen) und dieselben Abfragen senden |
| 06 | Auswertungen mit Python und `jq` auf erfundenen Daten | echt ausgeführt; Daten erfunden | mit echten Logs wiederholen (Datenschutz beachten) |
| 07 | Warnregeln als Python-Modell mit Sperrzeit und Selbsttest | Modell; Graylog nicht ausgeführt | Ereignisdefinitionen in Graylog anlegen (Menüs nicht bestätigt) |
| 08 | `logrotate` (auch `-d`), `find -mtime`, Hash-Funktionen in Python, `rsyslog` mit `mmanon`, `sha256sum` | echt im Container ausgeführt; Speicherbedarf als Rechnung | auf `log01` mit echten Datenmengen messen |
