# Monitoring und Logging – Übungsreihen

Praxisübungen zu Monitoring und Logging: Monitoring mit Zabbix, Prometheus und Grafana sowie PRTG, zentrales Logging mit Graylog und Elastic Stack, Ereignisprotokolle, Weiterleitung, Auswertung und Aufbewahrung. Jede Reihe liegt in einem eigenen Ordner mit Modulen, Material und Skripten.

## Reihen

| Ordner | Thema | Stand |
|---|---|---|
| [`monitoring-mit-zabbix/`](monitoring-mit-zabbix/) | Monitoring mit Zabbix (P17): 8 Module, 100 Unterrichtseinheiten | Entwurf, Zabbix 7.0.32 (aus dem Quellcode gebaut), PostgreSQL und `snmpd` im Cloud-Container ausgeführt; Pakete von zabbix.com, Windows-Agent, Proxy, Browser-Frontend, SNMPv3 und E-Mail nicht ausgeführt, Dokumentation nicht gelesen |
| [`monitoring-mit-prometheus-und-grafana/`](monitoring-mit-prometheus-und-grafana/) | Monitoring mit Prometheus und Grafana (P18): 8 Module, 100 Unterrichtseinheiten | Entwurf, Prometheus 2.45.3, Alertmanager 0.26.0 und `node_exporter` 1.7.0 im Cloud-Container ausgeführt (Messreihen erfunden); Grafana und `windows_exporter` nicht ausgeführt, Dokumentation nicht gelesen |
| [`zentrales-logging-mit-graylog-und-elastic-stack/`](zentrales-logging-mit-graylog-und-elastic-stack/) | Zentrales Logging mit Graylog und Elastic Stack (P19): 8 Module, 100 Unterrichtseinheiten | Entwurf, `rsyslog` 8.2312, `logrotate` und `jq` im Cloud-Container ausgeführt; Graylog, Elasticsearch/OpenSearch, Logstash und Beats nicht ausgeführt (Modelle in Python), Lizenzmodelle und Versionsstände nicht geprüft |
| [`monitoring-mit-prtg/`](monitoring-mit-prtg/) | Monitoring mit PRTG (P20): 8 Module, 96 Unterrichtseinheiten | Entwurf, `snmpd`, Skripte und Auswertungen im Cloud-Container ausgeführt; PRTG nicht ausgeführt (Modell in Python), Lizenzangaben nach Herstellerseite vom 20.11.2026 nur teilweise gelesen, Menünamen nicht bestätigt |
| [`windows-ereignisweiterleitung-und-ereignisprotokolle/`](windows-ereignisweiterleitung-und-ereignisprotokolle/) | Windows Event Forwarding und Ereignisprotokolle (P66): 8 Module, 45 Unterrichtseinheiten | Entwurf, Python-Modell mit erfundenen Ereignissen im Cloud-Container ausgeführt; Windows, Hyper-V, `wecutil` und `wevtutil` nicht ausgeführt, Microsoft-Dokumentation nur teilweise gelesen |

## Lizenz

- Skripte: MIT, siehe [`LICENSE`](LICENSE)
- Texte: CC BY 4.0, siehe [`LICENSE-DOCS.md`](LICENSE-DOCS.md)

Microsoft, Windows und Hyper-V sind Marken der Microsoft Corporation. Dieses Repository steht in keiner Verbindung zu den Markeninhabern. Der Teststatus jeder Reihe steht in deren README.
