# Anmerkungen zum Lehrplan P66

Beim Ausarbeiten und Testen aufgefallene Punkte. Der Lehrplan selbst wurde zusammen mit der Übungsreihe erstellt und danach **nicht** verändert.

| Nr. | Modul | Befund | Vorschlag |
|---|---|---|---|
| 1 | alle | **Ausführung:** Alle Skripte liefen im Cloud-Container (Ubuntu 24.04, kein systemd) mit erfundenen Ereignissen (`gen_events.py`, feste Zufallsfolge). **Es wurde kein Windows und kein Windows-Werkzeug ausgeführt.** Das Verhalten in einer Domäne wurde nicht getestet. | Übungen im Hyper-V-Labor nachvollziehen; Ausgaben vergleichen. |
| 2 | alle | **Quellen:** Die Seite zu `wecutil` wurde gelesen; die anderen genannten Seiten der Microsoft-Dokumentation nur als Suchauszüge. Die Ereignis-IDs 4720 und 7045 sowie Anmeldetypen stammen aus Fachwissen. | Seiten vollständig lesen; IDs belegen. |
| 3 | 01 | **Ereignisaufbau:** Die erfundenen Ereignisse sind vereinfacht (weniger Felder, ohne `Guid`, `Task`, `Keywords`); sie sind nicht gegen das Ereignisschema geprüft. | Mit echten Ereignissen vergleichen. |
| 4 | 02 | **Zeitabfrage:** XPath 1.0 vergleicht keine Zeichenketten mit `<` und `>`; das Verhalten von Windows (Funktion `timediff`) ist Fachwissen und nicht geprüft. Ob Windows alle Ausdrücke des Modells akzeptiert, wurde nicht geprüft. | Unter Windows prüfen. |
| 5 | 04 | **Prüfwerkzeug:** Die Regeln des Prüfwerkzeugs (Pflichtelemente, keine `EventSources` bei SourceInitiated) sind ein Lernmodell; die Datei wurde nicht mit `wecutil cs` eingelesen. Die Beispiel-XML weicht von der Dokumentation ab (Zielwerte, Abfrage, Sprache `de-DE`). | Mit `wecutil cs` in der Domäne prüfen. |
| 6 | 05 | **Hochrechnung:** Die Rechnung nimmt gleiche Raten und 1 KB je Ereignis an; die Faustregel von 3000 Ereignissen je Sekunde stammt aus einem Suchauszug. | Raten messen. |
| 7 | 07 | **Priorität:** Modul 7 ist Priorität 2; kein anderes Modul setzt es voraus. Facility und Schweregrad sind frei gewählt. | Bei Zeitmangel entfallen lassen. |
