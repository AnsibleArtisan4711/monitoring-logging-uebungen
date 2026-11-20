# Anmerkungen zum Lehrplan P18

Beim Ausarbeiten und Testen aufgefallene Punkte. Der Lehrplan selbst wurde zusammen mit der Übungsreihe erstellt und danach **nicht** verändert.

| Nr. | Modul | Befund | Vorschlag |
|---|---|---|---|
| 1 | alle | **Ausführung:** Alle Skripte liefen im Cloud-Container (Ubuntu 24.04, kein systemd) mit echtem Prometheus 2.45.3, Alertmanager 0.26.0 und `node_exporter` 1.7.0 (Ubuntu-Pakete). **Grafana und `windows_exporter` wurden nicht ausgeführt;** Hyper-V, Windows und systemd wurden nicht getestet. | Übungen im Hyper-V-Labor nachvollziehen; Ausgaben vergleichen. |
| 2 | alle | **Quellen:** Es wurde **keine** Seite der Herstellerdokumentation vollständig gelesen. Standardports (9090, 9093, 9100, 9182, 3000), Optionsnamen außerhalb der ausgeführten Programme und die Installation von Grafana sind Fachwissen und nicht bestätigt. | Dokumentation lesen; Ports und Optionen belegen. |
| 3 | 01 | **Zählerwerte:** Die Werte in Schritt 1 und 3 stammen vom echten Container und ändern sich bei jedem Lauf; die Zahl der Beanstandungen (27) hängt von der Version des Exporters ab. | Beim Vergleich nur die Struktur prüfen. |
| 4 | 03 | **Messreihen:** Alle Werte sind erfunden und rückwirkend eingespielt; ausgewertet wird zum festen Zeitpunkt 26.10.2026. Das 95. Perzentil ist eine Schätzung aus Eimergrenzen. | Mit echten Messwerten wiederholen. |
| 5 | 04 | **Alter der Sicherung:** Das Ergebnis der Abfrage in Schritt 4 hängt vom Datum des Laufs ab (Zeitstempel in der Datei ist fest). | Hinweis in der Übung beachten. |
| 6 | 06 | **Grafana:** Aufbau der Dashboard-JSON, Feldnamen, Panel-Typen und Bereitstellungsdateien sind Fachwissen und nicht gegen Grafana geprüft; das Verhalten bei fehlenden Daten („No data“) ist nicht geprüft. | In Grafana importieren und prüfen. |
| 7 | 07 | **Priorität:** Modul 7 ist Priorität 2; kein anderes Modul setzt es voraus. Die Voreinstellung von 15 Tagen und der Faustwert von 2 Byte je Sample sind nicht belegt. | Bei Zeitmangel entfallen lassen; Werte mit Dokumentation und Messung prüfen. |
| 8 | 08 | **Betrieb:** Der Betrieb unter systemd wurde nicht getestet. `--web.enable-admin-api` und `--web.enable-lifecycle` waren nur für die Übung aktiv. | Im Labor mit Zugriffsschutz prüfen. |
