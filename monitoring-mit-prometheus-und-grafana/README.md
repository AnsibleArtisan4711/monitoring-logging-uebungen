# Monitoring mit Prometheus und Grafana (P18)

Übungsreihe zu Monitoring mit Prometheus und Grafana: Metriken und Zeitreihen, Prometheus (Konfiguration, Scraping, PromQL), Exporter, Alarmregeln und Alertmanager, Grafana-Dashboards als Dateien, Aufbewahrung und Speicher sowie Betrieb, Sicherung und Abschlussprojekt. 8 Module, 100 Unterrichtseinheiten zu 45 Minuten, davon 1 Modul mit Priorität 2 (Vertiefung). Prometheus, Alertmanager und `node_exporter` laufen in den Übungen echt; Grafana und `windows_exporter` werden nicht ausgeführt. Die Aufgabentexte und Kontrollfragen stammen aus dem Lehrplan P18 (Reihe „Lehrplan-Prompts“, Datei `P18-monitoring-mit-prometheus-und-grafana.md`) und sind unverändert; Hinweise, Musterlösungen und Ergänzungen sind Teil der Ausarbeitung und gekennzeichnet.

> **Prüfstand, ehrlich:** **Im Cloud-Container ausgeführt.** Die Skripte starten echtes Prometheus 2.45.3, Alertmanager 0.26.0 und `node_exporter` 1.7.0 (Ubuntu 24.04) auf `127.0.0.1`; die Messreihen der Module 3, 5, 6 und 7 sind erfunden und werden mit `promtool` eingespielt. Die Ausgaben stehen in den Ordnern `beispiele/`. **Grafana und `windows_exporter` wurden nicht ausgeführt**; Befehle und Aufbau dazu stammen aus Fachwissen (keine Seite der Herstellerdokumentation vollständig gelesen). Offene Punkte: [`befehle-nicht-bestaetigt.md`](befehle-nicht-bestaetigt.md); Anmerkungen zum Lehrplan: [`lehrplan-korrekturen.md`](lehrplan-korrekturen.md).

## Umgebung

Zwei Linux-VMs und optional eine Windows-VM unter **Hyper-V** (Lehrplan): `mon01`, `lin01`, optional `win01` am privaten Switch `Lab-Monitoring` (`10.18.0.0/24`). Das Labor wurde **nicht** aufgebaut. Die Skripte brauchen die VMs nicht und arbeiten unter `/tmp/p18`.

## Module

| Nr. | Modul | Zeit | Prüfstand |
|---|---|---|---|
| 01 | [Metriken und Zeitreihen](01-metriken-und-zeitreihen/) | 9 h | Skript im Container ausgeführt (echter `node_exporter` 1.7.0, `promtool`). |
| 02 | [Prometheus und Scraping](02-prometheus-und-scraping/) | 10,5 h | Skript im Container ausgeführt (echtes Prometheus 2.45.3). |
| 03 | [Abfragen mit PromQL](03-promql/) | 10,5 h | Skript im Container ausgeführt (echtes Prometheus mit erfundener, rückwirkend eingespielter Messreihe). |
| 04 | [Exporter: node_exporter, eigene Exporter und windows_exporter](04-exporter/) | 10,5 h | Skript im Container ausgeführt (echter `node_exporter`, eigener Python-Exporter); `windows_exporter` nicht ausgeführt. |
| 05 | [Alarmregeln und Alertmanager](05-alarmierung/) | 9 h | Skript im Container ausgeführt (echte Programme `promtool`, `amtool`, `prometheus-alertmanager`). |
| 06 | [Grafana-Dashboards](06-grafana-dashboards/) | 9 h | Skript im Container ausgeführt; Grafana nicht ausgeführt (YAML, JSON, Abfragen gegen echtes Prometheus). |
| 07 | [Aufbewahrung und Speicher](07-aufbewahrung-und-speicher/) (Priorität 2) | 7,5 h | Skript im Container ausgeführt (echte Programme `prometheus`, `promtool`). |
| 08 | [Betrieb, Sicherung und Abschlussprojekt](08-betrieb-und-sicherung/) | 9 h | Skript im Container ausgeführt (echte Programme `prometheus`, `promtool`, `prometheus-node-exporter`). |

Summe 75 Stunden.

## Aufbau eines Moduls

Ordner `NN-kurzname/` mit `README.md`, der Übung `NN.1-….md` (Lernziele, Voraussetzungen, Grundbegriffe, Aufgaben, Hinweise, Kontrollfragen, einklappbare Musterlösung, Erweiterungen, Quellen), den Skripten und Beispieldaten des Moduls und einem Ordner `beispiele/` mit den echten Ausgaben der Läufe. Die Skripte der Module liegen im jeweiligen Modulordner und binden `../lab.sh` ein; `gen_data.py`, `webhook.py` und `exporter.py` liegen im Kursordner. Benötigte Pakete (Ubuntu): `prometheus`, `prometheus-alertmanager`, `prometheus-node-exporter`, `jq`, `curl`, `python3-yaml` und das Python-Paket `bcrypt` (getestet mit 5.0.0, per `pip` installiert).

## Hinweise

- Alle Messwerte, Namen und Adressen sind erfunden; verwenden Sie in Übungen keine echten Messdaten.
- Die Ports 19090 bis 19101 auf `127.0.0.1` müssen frei sein; Skripte beenden ihre Prozesse am Ende.
- Das Passwort aus Modul 8 ist ein Übungswert. Grafana-Befehle wurden nicht ausgeführt.

## Lizenz

- Skripte: MIT, siehe [`LICENSE`](LICENSE)
- Texte: CC BY 4.0, siehe [`LICENSE-DOCS.md`](LICENSE-DOCS.md)

*Lizenz: Text CC BY 4.0, Skripte MIT, siehe `LICENSE-DOCS.md` und `LICENSE` im Kursordner. Alle Personen, Firmen, Zahlen und Termine sind frei erfunden. Windows und Windows Server sind Marken der Microsoft Corporation; dieses Dokument steht in keiner Verbindung zu Microsoft.*
