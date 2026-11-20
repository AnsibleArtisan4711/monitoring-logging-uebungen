# Befehle und Aussagen, die nicht bestätigt sind

Prüfliste für den ersten Durchlauf in den Hyper-V-VMs: Befund und Datum eintragen, danach den Hinweis in der Übung entfernen. Legende: **Q** = gegen Quelle gelesen; **L** = im Labor (Container) ausgeführt; **–** = weder noch.

| Modul | Befehl oder Aussage | Status | Nächster Schritt |
|---|---|---|---|
| alle | Aufbau des Hyper-V-Labors (privater Switch `Lab-Logs`, `dc01`, `wec01`, `pc01`) | – | laut Lehrplan aufbauen und prüfen |
| 01 | Ereignisaufbau (XML) mit `lxml`, `xmllint --xpath` | Modell: L (erfundene Ereignisse) | mit echten Ereignissen (`wevtutil qe /f:xml`) vergleichen |
| 02 | Abfragen im XPath-Stil (`*[System[(EventID=4625)]]`) mit `lxml`; `wevtutil qe` nur als Text | Modell: L; `wevtutil`: nicht ausgeführt | unter Windows ausführen; Zeitabfragen mit der Dokumentation prüfen |
| 03 | Auswertung von 4624, 4625, 4634, 4740 in Python | Modell: L | mit echten Sicherheitsereignissen wiederholen |
| 04 | Abonnement-XML (Aufbau nach Wecutil-Seite), `winrm qc -q`, `wecutil qc /q`, `wecutil cs`, `wecutil gr`, `wecutil gs`, `gpupdate /force`, GPO SubscriptionManager | XML: L (Prüfung im Modell); Befehle: aus der Dokumentation, nicht ausgeführt | in der Domäne ausführen |
| 05 | Filtermengen und Hochrechnung in Python | Modell: L | mit gemessenen Raten wiederholen |
| 06 | `sha256sum`, Aufbewahrungsfrist, Rotation in Bash | L (Dateien im Container) | für Windows-Protokolle (`wevtutil`, Größenbegrenzung) prüfen |
| 07 | Syslog-Zeile im RFC-5424-Aufbau | Modell: L; Norm nicht gelesen | mit Syslog-Server und Norm prüfen |
| 08 | Erkennungsregeln in Python | Modell: L | mit echten Daten prüfen |
