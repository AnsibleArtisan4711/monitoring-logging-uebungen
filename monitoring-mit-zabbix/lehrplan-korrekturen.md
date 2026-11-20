# Anmerkungen zum Lehrplan P17

Beim Ausarbeiten und Testen aufgefallene Punkte. Der Lehrplan selbst wurde zusammen mit der Übungsreihe erstellt und danach **nicht** verändert.

| Nr. | Modul | Befund | Vorschlag |
|---|---|---|---|
| 1 | alle | **Ausführung:** Alle Skripte liefen im Cloud-Container (Ubuntu 24.04, kein systemd) mit echtem **Zabbix 7.0.32, aus dem Quellcode gebaut** (Ubuntu hat keine Zabbix-Pakete), PostgreSQL 16 und `snmpd` 5.9.4. **Nicht ausgeführt:** Installation aus den Paketen von zabbix.com, Windows-Agent, Proxy, Browser-Frontend, SNMPv3, SNMP-Traps, E-Mail-Versand. Hyper-V, Windows und systemd wurden nicht getestet. | Übungen im Hyper-V-Labor mit den Paketen nachvollziehen; Ausgaben vergleichen. |
| 2 | alle | **Quellen:** Es wurde **keine** Seite der Zabbix-Dokumentation vollständig gelesen. Standardports (10050, 10051), Paketnamen, Menünamen und das Verhalten von Proxy, SNMPv3 und Windows-Agent sind Fachwissen und nicht bestätigt. | Dokumentation lesen; Angaben belegen. |
| 3 | alle | **Skripte:** Die Skripte setzen den selbst gebauten Zabbix unter `/opt/zbx` voraus (siehe `aufbau-container.sh`, nicht als Ganzes erneut ausgeführt). Im Labor müssen Pfade (`ZBX`, `UI`) und der Start der Dienste angepasst werden. | Pfade in `lab.sh` anpassen. |
| 4 | 01 | **Zahlen:** 203 Tabellen, 356 Vorlagen, 18388 Items usw. gelten für **7.0.32**. Die Prozessliste hängt von der Konfiguration ab. | Beim Vergleich nur die Struktur prüfen. |
| 5 | 02 | **Kennwörter:** `uebung-zbx` und das neue Kennwort sind Übungswerte; das Standardkennwort des Benutzers `Admin` wird in der Übung sofort geändert. | In Produktion nie Standardkennwörter belassen. |
| 6 | 04 | **Windows-Agent:** Nur Beschreibung; Dienstname, Installationspfad und Konfiguration unter Windows sind nicht bestätigt. | Unter Windows prüfen. |
| 7 | 06 | **Priorität:** Modul 6 ist Priorität 2; kein anderes Modul setzt es voraus. „Sofort löschen“ ist nur für die Übung gewählt. | Bei Zeitmangel entfallen lassen. |
| 8 | 08 | **Abnahme:** Eine Zeile der Abnahmeliste (Port 1) ist absichtlich ein FEHLER. Gesichert wird nur die Konfiguration, nicht die Messwerte. | Für Messwerte ein eigenes Konzept ergänzen. |
