# Monitoring mit PRTG (P20)

Übungsreihe zu Monitoring mit PRTG: Aufbau und Installation, Sensoren und Geräte, Abfragen per WMI, SNMP und SSH, Benachrichtigungen, Karten und Berichte, Abhängigkeiten, eigene Sensoren (Skripte), Lizenzmodell der Gratisstufe und Betrieb. 8 Module, 96 Unterrichtseinheiten zu 45 Minuten, davon 1 Modul mit Priorität 2 (Vertiefung). PRTG wird nicht ausgeführt; SNMP, Skripte und Auswertungen laufen echt, das Verhalten von PRTG ist ein Modell. Die Aufgabentexte und Kontrollfragen stammen aus dem Lehrplan P20 (Reihe „Lehrplan-Prompts“, Datei `P20-monitoring-mit-prtg.md`) und sind unverändert; Hinweise, Musterlösungen und Ergänzungen sind Teil der Ausarbeitung und gekennzeichnet.

> **Prüfstand, ehrlich:** **Im Cloud-Container ausgeführt, PRTG nicht.** Die Skripte starten `snmpd` (net-snmp 5.9.4) und einen HTTP-Server auf `127.0.0.1`, erzeugen Skriptsensor-Ausgaben (XML/JSON) und werten erfundene Daten aus; Status, Benachrichtigung, Abhängigkeiten und Lizenzbudget sind **Modelle in Python**. Lizenz- und Formatangaben stammen von Herstellerseiten, gelesen am 20.11.2026 (nur teilweise). Die Ausgaben stehen in den Ordnern `beispiele/`. Offene Punkte: [`befehle-nicht-bestaetigt.md`](befehle-nicht-bestaetigt.md); Anmerkungen zum Lehrplan: [`lehrplan-korrekturen.md`](lehrplan-korrekturen.md).

## Umgebung

Drei VMs unter **Hyper-V** (Lehrplan): `prtg01` (Windows Server mit PRTG), `win01` (Windows) und `lin01` (Ubuntu) am privaten Switch `Lab-PRTG` (`10.20.0.0/24`). Das Labor wurde **nicht** aufgebaut. Die Skripte brauchen die VMs nicht und arbeiten unter `/tmp/p20`.

## Module

| Nr. | Modul | Zeit | Prüfstand |
|---|---|---|---|
| 01 | [Aufbau und Installation](01-aufbau-und-installation/) | 7,5 h | Skript im Container ausgeführt (Modell und echte Portprüfung); PRTG nicht ausgeführt. |
| 02 | [Sensoren und Geräte](02-sensoren-und-geraete/) | 9 h | Skript im Container ausgeführt (echte Prüfungen gegen einen lokalen HTTP-Server; Statuslogik als Modell). |
| 03 | [Abfragen per WMI, SNMP und SSH](03-wmi-snmp-ssh/) | 10,5 h | Skript im Container ausgeführt (echter `snmpd` 5.9.4); WMI und SSH-Sensoren nicht ausgeführt. |
| 04 | [Benachrichtigungen](04-benachrichtigungen/) | 9 h | Skript im Container ausgeführt (Ablauf als Modell; Webhook echt auf `127.0.0.1`). |
| 05 | [Karten und Berichte](05-karten-und-berichte/) (Priorität 2) | 7,5 h | Skript im Container ausgeführt (Auswertung erfundener Daten, SVG mit `xmllint` geprüft); PRTG nicht ausgeführt. |
| 06 | [Abhängigkeiten](06-abhaengigkeiten/) | 7,5 h | Skript im Container ausgeführt (Modell in Python); PRTG nicht ausgeführt. |
| 07 | [Eigene Sensoren mit Skripten](07-eigene-sensoren-skripte/) | 12 h | Skripte im Container ausgeführt (Bash, Python, `xmllint`, `jq`); gegen PRTG nicht getestet. |
| 08 | [Lizenzmodell der Gratisstufe und Betrieb](08-lizenz-und-betrieb/) | 9 h | Skript im Container ausgeführt (Rechnungen, `tar`-Sicherung); Lizenzangaben nach Herstellerseite vom 20.11.2026. |

Summe 72 Stunden.

## Aufbau eines Moduls

Ordner `NN-kurzname/` mit `README.md`, der Übung `NN.1-….md` (Lernziele, Voraussetzungen, Grundbegriffe, Aufgaben, Hinweise, Kontrollfragen, einklappbare Musterlösung, Erweiterungen, Quellen), den Skripten und Beispieldaten des Moduls und einem Ordner `beispiele/` mit den echten Ausgaben der Läufe. Die Skripte der Module liegen im jeweiligen Modulordner und binden `../lab.sh` ein; `prtg.py` (Modell) liegt im Kursordner. Benötigte Pakete (Ubuntu): `snmpd`, `snmp`, `jq`, `curl`, `libxml2-utils` (für `xmllint`), `netcat-openbsd`, `python3`.

## Hinweise

- Alle Messwerte, Namen und Adressen sind erfunden; Community und Kennwörter sind Übungswerte.
- Die Ports 11162 (UDP), 18201 und 18202 auf `127.0.0.1` müssen frei sein; Skripte beenden ihre Prozesse am Ende.
- PRTG-Menünamen und -Einstellungen sind nicht bestätigt; Lizenzangaben gelten mit Stand 20.11.2026.

## Lizenz

- Skripte: MIT, siehe [`LICENSE`](LICENSE)
- Texte: CC BY 4.0, siehe [`LICENSE-DOCS.md`](LICENSE-DOCS.md)

*Lizenz: Text CC BY 4.0, Skripte MIT, siehe `LICENSE-DOCS.md` und `LICENSE` im Kursordner. Alle Personen, Firmen, Zahlen und Termine sind frei erfunden. Windows und Windows Server sind Marken der Microsoft Corporation; dieses Dokument steht in keiner Verbindung zu Microsoft.*
