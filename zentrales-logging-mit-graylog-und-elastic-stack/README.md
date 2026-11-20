# Zentrales Logging mit Graylog und Elastic Stack (P19)

Übungsreihe zu zentralem Logging mit Graylog und dem Elastic Stack: Logquellen und Formate, Erfassung und Weiterleitung, Graylog (Inputs, GELF, Streams, Pipelines), Elastic Stack im Überblick, Suchen und Auswerten, Warnungen sowie Aufbewahrung, Datenschutz und Betrieb. 8 Module, 100 Unterrichtseinheiten zu 45 Minuten, davon 1 Modul mit Priorität 2 (Vertiefung). `rsyslog`, `logrotate` und `jq` laufen echt; Graylog und der Elastic Stack werden nicht ausgeführt (Modelle in Python). Die Aufgabentexte und Kontrollfragen stammen aus dem Lehrplan P19 (Reihe „Lehrplan-Prompts“, Datei `P19-zentrales-logging-mit-graylog-und-elastic-stack.md`) und sind unverändert; Hinweise, Musterlösungen und Ergänzungen sind Teil der Ausarbeitung und gekennzeichnet.

> **Prüfstand, ehrlich:** **Im Cloud-Container ausgeführt.** Die Skripte starten echte `rsyslog`-Instanzen (8.2312) auf `127.0.0.1` und nutzen `logger`, `logrotate` und `jq`; die Logdaten der Module 5 bis 8 sind erfunden. **Graylog, Elasticsearch/OpenSearch, Logstash, Beats und MongoDB wurden nicht ausgeführt**; Module 3 bis 5 und die Regeln in Modul 7 sind Modelle in Python (GELF über echte UDP-Datagramme). Lizenzmodelle und Versionsstände sind **nicht** geprüft. Die Ausgaben stehen in den Ordnern `beispiele/`. Offene Punkte: [`befehle-nicht-bestaetigt.md`](befehle-nicht-bestaetigt.md); Anmerkungen zum Lehrplan: [`lehrplan-korrekturen.md`](lehrplan-korrekturen.md).

## Umgebung

Drei VMs unter **Hyper-V** (Lehrplan): `log01` (Log-Server mit viel RAM), `lin01` und `win01` (Logquellen) am privaten Switch `Lab-Logging` (`10.19.0.0/24`). Das Labor wurde **nicht** aufgebaut. Die Skripte brauchen die VMs nicht und arbeiten unter `/tmp/p19`.

## Module

| Nr. | Modul | Zeit | Prüfstand |
|---|---|---|---|
| 01 | [Logquellen und Formate](01-logquellen-und-formate/) | 9 h | Skript im Container ausgeführt (echtes `rsyslog` 8.2312, `logger`). |
| 02 | [Erfassung und Weiterleitung](02-erfassung-und-weiterleitung/) | 10,5 h | Skript im Container ausgeführt (zwei echte `rsyslog`-Instanzen auf `127.0.0.1`). |
| 03 | [Graylog: Aufbau, Inputs und GELF](03-graylog-inputs-und-gelf/) | 10,5 h | Skript im Container ausgeführt (Modell in Python, echte UDP-Datagramme auf `127.0.0.1`); Graylog nicht ausgeführt. |
| 04 | [Graylog: Streams und Pipelines](04-streams-und-pipelines/) | 10,5 h | Skript im Container ausgeführt (Modell in Python mit erfundenen Daten); Graylog nicht ausgeführt. |
| 05 | [Elastic Stack im Überblick](05-elastic-stack-im-ueberblick/) | 9 h | Skript im Container ausgeführt (Modell mit der Schreibweise von Elasticsearch, Gegenprobe mit `jq`); Elastic Stack nicht ausgeführt. |
| 06 | [Suchen und Auswerten](06-suchen-und-auswerten/) | 9 h | Skript im Container ausgeführt (Auswertung erfundener Daten mit Python und `jq`). |
| 07 | [Warnungen](07-warnungen/) (Priorität 2) | 7,5 h | Skript im Container ausgeführt (Modell in Python mit erfundenen Daten). |
| 08 | [Aufbewahrung, Datenschutz und Betrieb](08-aufbewahrung-datenschutz-betrieb/) | 9 h | Skript im Container ausgeführt (echte Programme `logrotate`, `rsyslog` mit `mmanon`; Rechnungen in Python). |

Summe 75 Stunden.

## Aufbau eines Moduls

Ordner `NN-kurzname/` mit `README.md`, der Übung `NN.1-….md` (Lernziele, Voraussetzungen, Grundbegriffe, Aufgaben, Hinweise, Kontrollfragen, einklappbare Musterlösung, Erweiterungen, Quellen), den Skripten und Beispieldaten des Moduls und einem Ordner `beispiele/` mit den echten Ausgaben der Läufe. Die Skripte der Module liegen im jeweiligen Modulordner und binden `../lab.sh` ein; `gen_logs.py`, `gelf.py`, `pipeline.py` und `esmodell.py` liegen im Kursordner. Benötigte Pakete (Ubuntu): `rsyslog`, `logrotate`, `jq`, `python3`, `netcat-openbsd`.

## Hinweise

- Alle Logdaten, Namen und Adressen sind erfunden; verwenden Sie in Übungen keine echten Logdaten mit Personenbezug.
- Die Ports 15514, 15515, 15517 und 12201 auf `127.0.0.1` müssen frei sein; Skripte beenden ihre Prozesse am Ende.
- Lizenzmodelle und Versionsstände von Graylog und Elastic ändern sich: vor einem Einsatz mit Datum prüfen.

## Lizenz

- Skripte: MIT, siehe [`LICENSE`](LICENSE)
- Texte: CC BY 4.0, siehe [`LICENSE-DOCS.md`](LICENSE-DOCS.md)

*Lizenz: Text CC BY 4.0, Skripte MIT, siehe `LICENSE-DOCS.md` und `LICENSE` im Kursordner. Alle Personen, Firmen, Zahlen und Termine sind frei erfunden. Windows und Windows Server sind Marken der Microsoft Corporation; dieses Dokument steht in keiner Verbindung zu Microsoft.*
