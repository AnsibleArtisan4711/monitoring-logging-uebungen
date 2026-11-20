# Anmerkungen zum Lehrplan P19

Beim Ausarbeiten und Testen aufgefallene Punkte. Der Lehrplan selbst wurde zusammen mit der Übungsreihe erstellt und danach **nicht** verändert.

| Nr. | Modul | Befund | Vorschlag |
|---|---|---|---|
| 1 | alle | **Ausführung:** Alle Skripte liefen im Cloud-Container (Ubuntu 24.04, kein systemd) mit echtem `rsyslog` 8.2312, `logrotate`, `logger` und `jq`. **Graylog, MongoDB, Elasticsearch, OpenSearch, Logstash, Beats und Kibana wurden nicht ausgeführt;** deren Module sind Modelle in Python. Hyper-V, Windows und systemd wurden nicht getestet. | Übungen im Hyper-V-Labor nachvollziehen; Modelle gegen die echten Programme prüfen. |
| 2 | alle | **Quellen und Stand:** Es wurde **keine** Seite der Herstellerdokumentation von Graylog oder Elastic gelesen. Standardports, Menünamen, Schreibweisen der Regelsprache und Beispielkonfigurationen sind Fachwissen und nicht bestätigt. **Lizenzmodelle und Versionsstände** wurden nicht geprüft und müssen vor dem Einsatz mit Datum auf den Herstellerseiten geprüft werden. | Dokumentation lesen; Stand und Lizenz mit Datum belegen. |
| 3 | 01 | **Facility `kern`:** `logger -p kern.crit` wird von `rsyslog` der Facility `user` zugeordnet (PRI 10 statt 2); das Format von `logger` (RFC 3164 oder 5424) hängt von der Version und den Optionen ab. | Beim Vergleich die Optionen des Skripts beachten. |
| 4 | 02 | **Zeilen mit Verbindungsproblem:** Die Zahl (5) hängt vom Takt der Wiederholversuche ab. | Nur die Aussage „nichts kommt an“ vergleichen. |
| 5 | 03 | **GELF-Input:** Der Input ist ein Modell; gegen Graylog wurde nichts getestet. Größe und Zerlegung (4170 Byte in 3 Teilen) hängen vom Modell ab. | Gegen ein echtes Graylog testen. |
| 6 | 05 | **Index:** Der „Index“ ist ein selbstgebautes Modell; Analyse, Relevanz und Aggregationen sind stark vereinfacht. | Mit Elasticsearch oder OpenSearch prüfen. |
| 7 | 07 | **Priorität:** Modul 7 ist Priorität 2; kein anderes Modul setzt es voraus. | Bei Zeitmangel entfallen lassen. |
| 8 | 08 | **Datenschutz:** Die Einordnung der Felder ist eine Annahme und keine Rechtsberatung. Der Speicherbedarf ist eine Rechnung mit Annahmen (100 Rechner, 10 % Verdichtung), nicht gemessen. | Mit Datenschutzbeauftragten klären; mit echten Daten messen. |
