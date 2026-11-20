# Monitoring mit Zabbix (P17)

Übungsreihe zu Monitoring mit Zabbix: Architektur und Datenmodell, Installation, Hosts, Items und Trigger, Vorlagen und Agent, SNMP, Auto-Discovery, Benachrichtigungen, Dashboards und Wartungsfenster sowie Leistung, Betrieb und Sicherung. 8 Module, 100 Unterrichtseinheiten zu 45 Minuten, davon 1 Modul mit Priorität 2 (Vertiefung). Zabbix 7.0.32 (aus dem Quellcode gebaut), PostgreSQL und `snmpd` laufen in den Übungen echt; Pakete, Windows-Agent, Proxy und Browser-Frontend werden nicht ausgeführt. Die Aufgabentexte und Kontrollfragen stammen aus dem Lehrplan P17 (Reihe „Lehrplan-Prompts“, Datei `P17-monitoring-mit-zabbix.md`) und sind unverändert; Hinweise, Musterlösungen und Ergänzungen sind Teil der Ausarbeitung und gekennzeichnet.

> **Prüfstand, ehrlich:** **Im Cloud-Container ausgeführt.** Die Skripte starten echten Zabbix-Server und -Agenten (**7.0.32, aus dem Quellcode gebaut**, weil Ubuntu 24.04 keine Zabbix-Pakete hat), PostgreSQL 16 und `snmpd` auf `127.0.0.1` und steuern Zabbix über die API. **Nicht ausgeführt:** Installation aus den Paketen von zabbix.com, Windows-Agent, Proxy, Browser-Frontend, SNMPv3, SNMP-Traps, E-Mail. Befehle dazu stammen aus Fachwissen (keine Seite der Dokumentation vollständig gelesen). Die Ausgaben stehen in den Ordnern `beispiele/`. Offene Punkte: [`befehle-nicht-bestaetigt.md`](befehle-nicht-bestaetigt.md); Anmerkungen zum Lehrplan: [`lehrplan-korrekturen.md`](lehrplan-korrekturen.md).

## Umgebung

Drei VMs unter **Hyper-V** (Lehrplan): `zbx01` (Zabbix-Server), `lin01` und `win01` (überwachte Hosts) am privaten Switch `Lab-Zabbix` (`10.17.0.0/24`). Das Labor wurde **nicht** aufgebaut. Die Skripte brauchen die VMs nicht, setzen aber den gebauten Zabbix unter `/opt/zbx` voraus und arbeiten unter `/tmp/p17`.

## Module

| Nr. | Modul | Zeit | Prüfstand |
|---|---|---|---|
| 01 | [Architektur und Datenmodell](01-architektur-und-datenmodell/) | 9 h | Skript im Container ausgeführt (echtes Zabbix 7.0.32, aus dem Quellcode gebaut, PostgreSQL 16). |
| 02 | [Installation](02-installation/) | 9 h | Skript im Container ausgeführt (echtes Zabbix 7.0.32 aus dem Quellcode, PostgreSQL 16); Paketinstallation nicht ausgeführt. |
| 03 | [Hosts, Items und Trigger](03-hosts-items-trigger/) | 12 h | Skript im Container ausgeführt (echtes Zabbix 7.0.32, Agent und API). |
| 04 | [Vorlagen und Agent](04-vorlagen-und-agent/) | 9 h | Skript im Container ausgeführt (echtes Zabbix 7.0.32, `zabbix_sender`); Windows-Agent nicht ausgeführt. |
| 05 | [SNMP](05-snmp/) | 10,5 h | Skript im Container ausgeführt (echtes Zabbix 7.0.32 und `snmpd` 5.9.4); SNMPv3 und Traps nicht getestet. |
| 06 | [Auto-Discovery](06-auto-discovery/) (Priorität 2) | 9 h | Skript im Container ausgeführt (echtes Zabbix 7.0.32, Entdeckungsskript in Bash). |
| 07 | [Benachrichtigungen, Dashboards und Wartungsfenster](07-benachrichtigung-dashboards/) | 9 h | Skript im Container ausgeführt (echtes Zabbix 7.0.32 mit Skript-Medientyp); E-Mail und Browser nicht getestet. |
| 08 | [Leistung, Betrieb und Sicherung](08-betrieb-und-sicherung/) | 7,5 h | Skript im Container ausgeführt (echtes Zabbix 7.0.32, PostgreSQL 16, `pg_dump`). |

Summe 75 Stunden.

## Aufbau eines Moduls

Ordner `NN-kurzname/` mit `README.md`, der Übung `NN.1-….md` (Lernziele, Voraussetzungen, Grundbegriffe, Aufgaben, Hinweise, Kontrollfragen, einklappbare Musterlösung, Erweiterungen, Quellen), den Skripten und Beispieldaten des Moduls und einem Ordner `beispiele/` mit den echten Ausgaben der Läufe. Die Skripte der Module liegen im jeweiligen Modulordner und binden `../lab.sh` ein; `aufbau-container.sh` beschreibt den Bau von Zabbix aus dem Quellcode. Benötigte Pakete (Ubuntu): `postgresql`, PHP (`php-cli`, `php-pgsql`, `php-bcmath`, `php-mbstring`, `php-gd`, `php-xml`, `php-curl`), `snmp`, `snmpd`, `jq`, `curl`, Bauwerkzeuge und Bibliotheken (siehe `aufbau-container.sh`).

## Hinweise

- Alle Namen, Adressen und Kennwörter sind Übungswerte; verwenden Sie sie nicht außerhalb des Labors.
- Die Ports 11050, 11051, 11161, 15432 und 18080 auf `127.0.0.1` müssen frei sein; Skripte beenden ihre Prozesse am Ende.
- Das Standardkennwort von Zabbix wird nur zur Übung verwendet und sofort geändert.

## Lizenz

- Skripte: MIT, siehe [`LICENSE`](LICENSE)
- Texte: CC BY 4.0, siehe [`LICENSE-DOCS.md`](LICENSE-DOCS.md)

*Lizenz: Text CC BY 4.0, Skripte MIT, siehe `LICENSE-DOCS.md` und `LICENSE` im Kursordner. Alle Personen, Firmen, Zahlen und Termine sind frei erfunden. Windows und Windows Server sind Marken der Microsoft Corporation; dieses Dokument steht in keiner Verbindung zu Microsoft.*
