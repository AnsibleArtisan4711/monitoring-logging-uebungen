# Befehle und Aussagen, die nicht bestätigt sind

Prüfliste für den ersten Durchlauf in den Hyper-V-VMs: Befund und Datum eintragen, danach den Hinweis in der Übung entfernen. Legende: **Q** = gegen Quelle gelesen; **L** = im Labor (Container) ausgeführt; **–** = weder noch.

| Modul | Befehl oder Aussage | Status | Nächster Schritt |
|---|---|---|---|
| alle | Aufbau des Hyper-V-Labors (privater Switch `Lab-Monitoring`, `mon01`, `lin01`, optional `win01`) | – | laut Lehrplan aufbauen und prüfen |
| 01 | `prometheus-node-exporter` (Textformat), `curl`, `promtool check metrics` | echt im Container ausgeführt (Ubuntu 24.04, `node_exporter` 1.7.0) | auf `lin01` mit dem installierten Stand wiederholen |
| 02 | `promtool check config`, `prometheus` (Konfiguration, `static_configs`, `file_sd_configs`, `relabel_configs`), Abfrage von `/api/v1/targets` | echt im Container ausgeführt (Prometheus 2.45.3) | auf `mon01` mit dem installierten Stand wiederholen |
| 03 | PromQL-Abfragen über die HTTP-API (`/api/v1/query`) auf rückwirkend eingespielte, erfundene Messreihen (`promtool tsdb create-blocks-from openmetrics`) | echt ausgeführt; Messwerte erfunden | mit echten Messwerten wiederholen |
| 04 | Textfile-Collector, eigener Python-Exporter, `windows_exporter`-Konfiguration | Textfile und Exporter: echt; `windows_exporter`: nur Syntax der Prometheus-Datei geprüft, Programm nicht ausgeführt | `windows_exporter` auf `win01` installieren; Port und Sammler prüfen |
| 05 | `promtool check rules`, `promtool test rules`, `amtool check-config`, `amtool config routes`, `amtool alert add`, `amtool silence`, Webhook (Python) | echt im Container ausgeführt (Alertmanager 0.26.0) | mit E-Mail- oder Chat-Empfänger im Labor wiederholen |
| 06 | Bereitstellungsdateien (YAML), Dashboard-JSON, `jq`; Panel-Abfragen gegen Prometheus | YAML/JSON/Abfragen echt; **Grafana nicht ausgeführt** | Grafana auf `mon01` installieren (Quelle und Version prüfen), Dateien ablegen, Ergebnis vergleichen |
| 07 | `promtool tsdb list`, `promtool tsdb analyze`, Recording Rule, Startoptionen für die Aufbewahrung, Schnappschuss, `delete_series`, `clean_tombstones` | echt im Container ausgeführt | Faustwert von 2 Byte je Sample mit echten Daten prüfen |
| 08 | `/-/healthy`, `/-/ready`, `/-/reload`, `promtool check web-config`, Basic Auth mit bcrypt, Schnappschuss und Wiederherstellung, Abnahmeliste | echt im Container ausgeführt; kein systemd | Dienste unter systemd auf `mon01` einrichten und Neustart testen |
