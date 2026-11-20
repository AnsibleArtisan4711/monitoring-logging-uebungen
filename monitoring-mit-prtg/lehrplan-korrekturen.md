# Anmerkungen zum Lehrplan P20

Beim Ausarbeiten und Testen aufgefallene Punkte. Der Lehrplan selbst wurde zusammen mit der Übungsreihe erstellt und danach **nicht** verändert.

| Nr. | Modul | Befund | Vorschlag |
|---|---|---|---|
| 1 | alle | **Ausführung:** PRTG läuft nur unter Windows und wurde **nicht** ausgeführt. Echt liefen `snmpd`, ein lokaler HTTP-Server, Skripte und Auswertungen im Cloud-Container (Ubuntu 24.04). Statuslogik, Benachrichtigung, Abhängigkeiten und Lizenzbudget sind Modelle in Python (`prtg.py`) nach den Angaben im Lehrplan. Hyper-V und Windows wurden nicht getestet. | Übungen im Hyper-V-Labor mit PRTG nachvollziehen und die Modelle gegen das echte Verhalten prüfen. |
| 2 | alle | **Quellen:** Gelesen wurden am 20.11.2026 (nur die von einem Abrufwerkzeug zusammengefassten Teile) die Handbuchseiten „Available Licenses“, „EXE/Script Advanced Sensor“ und „Custom Sensors“ von Paessler. Menünamen, Einstellungen, Standardports, Systemanforderungen und das Verhalten bei Überschreitung der Sensorgrenze sind **nicht bestätigt**. | Dokumentation lesen; Angaben belegen. |
| 3 | 01 | **Schwellen:** Die Mindestwerte der Vorabprüfung (8 GB RAM, 60 GB frei) sind Übungswerte, keine Herstellerangaben; Port 23560 für die Probe ist nicht bestätigt. | Anforderungen beim Hersteller nachlesen. |
| 4 | 02 | **Statuslogik:** „Down (teilweise)“, die Zahl der Fehlversuche und die Grenzen sind ein Modell; in PRTG heißen die Einstellungen anders (nicht bestätigt). | In PRTG prüfen. |
| 5 | 03 | **SNMP:** Die Zeilenzahl der Systemgruppe (37) hängt von der Version von `snmpd` ab; Community im Klartext nur für die Übung. | Beim Vergleich nur die Struktur prüfen. |
| 6 | 05 | **Priorität:** Modul 5 ist Priorität 2; kein anderes Modul setzt es voraus. Die Messdaten sind erfunden. | Bei Zeitmangel entfallen lassen. |
| 7 | 07 | **Format:** Bestätigt sind `prtg`, `result`, `channel`, `value`, `unit`, `float`, `limitmaxerror`, `text`, `error`. `limitmaxwarning` und `limitmode` sind **nicht bestätigt**. Ablageort und Endungen gelten mit Stand 20.11.2026. | Seite „Custom Sensors“ vollständig lesen. |
| 8 | 08 | **Lizenz:** Test 30 Tage, danach Freeware bis 100 Sensoren (Stand 20.11.2026). Zahlen der kommerziellen Lizenzen, die Zählweise des Testendes und die Folgen einer Überschreitung sind nicht bestätigt. | Vor der Planung beim Hersteller prüfen. |
