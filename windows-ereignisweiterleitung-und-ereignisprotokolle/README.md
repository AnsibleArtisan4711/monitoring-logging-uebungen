# Windows-Ereignisweiterleitung und Ereignisprotokolle (P66)

Übungsreihe zur Windows-Ereignisweiterleitung und zu Ereignisprotokollen: Aufbau von Ereignissen, Abfragen im XPath-Stil, Auswertung von Anmeldeereignissen, Abonnements der Ereignisweiterleitung, Filter und Mengenplanung, Aufbewahrung und Nachweis, Umsetzung nach Syslog sowie Erkennungsregeln und Abschlussprojekt. 8 Module, 45 Unterrichtseinheiten zu 45 Minuten, davon 1 Modul mit Priorität 2 (Vertiefung). Die Übungen laufen als Modell mit erfundenen Ereignissen; Windows wird nicht ausgeführt. Die Aufgabentexte und Kontrollfragen stammen aus dem Lehrplan P66 (Reihe „Lehrplan-Prompts“, Datei `P66-windows-event-forwarding-und-ereignisprotokolle.md`) und sind unverändert; Hinweise, Musterlösungen und Ergänzungen sind Teil der Ausarbeitung und gekennzeichnet.

> **Prüfstand, ehrlich:** **Im Cloud-Container ausgeführt, kein Windows.** Die Skripte arbeiten mit erfundenen Ereignissen im Aufbau von Windows-Ereignissen (Python 3, `lxml`, `xmllint`, Bash unter Ubuntu 24.04); die Ausgaben stehen in den Ordnern `beispiele/`. **`wecutil`, `winrm`, `wevtutil`, Gruppenrichtlinien und Syslog-Produkte wurden nicht ausgeführt**; deren Befehle stehen als Text und stammen teils aus der Microsoft-Dokumentation (nur Teile gelesen). Offene Punkte: [`befehle-nicht-bestaetigt.md`](befehle-nicht-bestaetigt.md); Anmerkungen zum Lehrplan: [`lehrplan-korrekturen.md`](lehrplan-korrekturen.md).

## Umgebung

Drei Windows-VMs unter **Hyper-V** (Lehrplan): `dc01`, `wec01`, `pc01` am privaten Switch `Lab-Logs` (`10.66.0.0/24`); optional `log01` (Linux). Das Labor wurde **nicht** aufgebaut. Die Skripte brauchen kein Windows und arbeiten unter `/tmp/p66`.

## Module

| Nr. | Modul | Zeit | Prüfstand |
|---|---|---|---|
| 01 | [Ereignisse und Protokollkanäle](01-ereignisse-und-protokollkanaele/) | 3,75 h | Skript im Container ausgeführt (erfundene Ereignisse). |
| 02 | [Ereignisabfragen im XPath-Stil](02-ereignisabfragen/) | 4,5 h | Skript im Container ausgeführt (Modell). |
| 03 | [Anmeldeereignisse auswerten](03-anmeldeereignisse-auswerten/) | 4,5 h | Skript im Container ausgeführt (Modell). |
| 04 | [Abonnements der Ereignisweiterleitung](04-abonnements-der-ereignisweiterleitung/) | 4,5 h | Skript im Container ausgeführt (Modell); Windows-Teil nicht ausgeführt. |
| 05 | [Filter und Mengenplanung](05-filter-und-mengenplanung/) | 3,75 h | Skript im Container ausgeführt (Modellrechnung). |
| 06 | [Aufbewahrung und Nachweis](06-aufbewahrung-und-nachweis/) | 4,5 h | Skript im Container ausgeführt (Modell mit Dateien). |
| 07 | [Weiterleitung nach Syslog](07-weiterleitung-nach-syslog/) (Priorität 2) | 3,75 h | Skript im Container ausgeführt (Modell). |
| 08 | [Erkennungsregeln und Abschlussprojekt](08-erkennungsregeln-und-abschlussprojekt/) | 4,5 h | Skript im Container ausgeführt (Modell). |

Summe 33,75 Stunden.

## Aufbau eines Moduls

Ordner `NN-kurzname/` mit `README.md`, der Übung `NN.1-….md` (Lernziele, Voraussetzungen, Grundbegriffe, Aufgaben, Hinweise, Kontrollfragen, einklappbare Musterlösung, Erweiterungen, Quellen), den Skripten und Beispieldaten des Moduls und einem Ordner `beispiele/` mit den echten Ausgaben der Läufe. Die Skripte der Module liegen im jeweiligen Modulordner und binden `../lab.sh` ein; `gen_events.py` und `evlib.py` liegen im Kursordner.

## Hinweise

- Alle Ereignisse, Namen und Adressen sind erfunden; verwenden Sie in Übungen keine echten Protokolle.
- Die Befehle in `abonnement.sh` und `ereignisse.sh` (Textausgaben) wurden nicht ausgeführt.
- Rechtliche Hinweise (Datenschutz, Aufbewahrung) wurden nicht geprüft.

## Lizenz

- Skripte: MIT, siehe [`LICENSE`](LICENSE)
- Texte: CC BY 4.0, siehe [`LICENSE-DOCS.md`](LICENSE-DOCS.md)

*Lizenz: Text CC BY 4.0, Skripte MIT, siehe `LICENSE-DOCS.md` und `LICENSE` im Kursordner. Alle Personen, Firmen, Zahlen und Termine sind frei erfunden. Windows und Windows Server sind Marken der Microsoft Corporation; dieses Dokument steht in keiner Verbindung zu Microsoft.*
