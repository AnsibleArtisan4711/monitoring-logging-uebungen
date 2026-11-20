# Befehle und Aussagen, die nicht bestätigt sind

Prüfliste für den ersten Durchlauf in den Hyper-V-VMs: Befund und Datum eintragen, danach den Hinweis in der Übung entfernen. Legende: **Q** = gegen Quelle gelesen; **L** = im Labor (Container) ausgeführt; **–** = weder noch.

| Modul | Befehl oder Aussage | Status | Nächster Schritt |
|---|---|---|---|
| alle | Aufbau des Hyper-V-Labors (privater Switch `Lab-PRTG`, `prtg01`, `win01`, `lin01`) | – | laut Lehrplan aufbauen und prüfen |
| 01 | Vorabprüfung (Python-Modell mit Übungsschwellen), TCP-Portprüfung auf `127.0.0.1` | echt im Container ausgeführt; **PRTG nicht ausgeführt** | Anforderungen aus der Herstellerdokumentation übernehmen; Installation auf `prtg01` |
| 02 | TCP-/HTTP-Prüfungen gegen `python3 -m http.server`, Statuslogik und Sensorzählung (Python-Modell) | Prüfungen echt; Statuslogik Modell | Sensoren in PRTG anlegen und das Verhalten vergleichen |
| 03 | `snmpd`, `snmpget`, `snmpwalk`, `snmpset` (net-snmp 5.9.4), lokale Befehle für den SSH-Sensor; WMI nur als Liste | SNMP echt; WMI und SSH-Sensor **nicht ausgeführt** | SNMP-, WMI- und SSH-Sensoren auf `win01` und `lin01` einrichten |
| 04 | Benachrichtigungslogik (Python-Modell), Webhook-Empfänger und `curl` | Webhook echt auf `127.0.0.1`; Logik Modell | Benachrichtigung mit SMTP und Webhook in PRTG einrichten (Menünamen nicht bestätigt) |
| 05 | Auswertung erfundener Daten (Python, `awk`), SVG-Karte, `xmllint` | echt ausgeführt; Berichts- und Kartenfunktion von PRTG nicht ausgeführt | Berichte und Karten in PRTG erzeugen |
| 06 | Abhängigkeitsbaum, Pausieren, Zyklenprüfung (Python-Modell) | Modell | Verhalten in PRTG nachprüfen (insbesondere bei Zyklen) |
| 07 | Skripte mit XML- und JSON-Ausgabe, `xmllint`, `jq`, Prüfer in Python, `timeout` | Skripte echt; **nicht gegen PRTG getestet** | Skripte im Ordner `\Custom Sensors\EXEXML` ablegen (Windows-Probe) und als Sensor einrichten |
| 08 | Rechnen mit Sensorzahlen und Datum, `tar`, `sha256sum`, Abnahmeliste | echt ausgeführt; Lizenzangaben nach Herstellerseite vom 20.11.2026 | Lizenzbedingungen erneut prüfen; Sicherung mit den Mitteln von PRTG testen |
