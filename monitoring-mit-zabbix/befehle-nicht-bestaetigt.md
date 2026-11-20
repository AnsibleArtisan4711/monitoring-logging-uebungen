# Befehle und Aussagen, die nicht bestätigt sind

Prüfliste für den ersten Durchlauf in den Hyper-V-VMs: Befund und Datum eintragen, danach den Hinweis in der Übung entfernen. Legende: **Q** = gegen Quelle gelesen; **L** = im Labor (Container) ausgeführt; **–** = weder noch.

| Modul | Befehl oder Aussage | Status | Nächster Schritt |
|---|---|---|---|
| alle | Aufbau des Hyper-V-Labors (privater Switch `Lab-Zabbix`, `zbx01`, `lin01`, `win01`) | – | laut Lehrplan aufbauen und prüfen |
| 01 | `zabbix_server -V`, `zabbix_agentd -V`, `zabbix_get`, API (`apiinfo.version`, `host.get`, `template.get`), SQL-Abfragen (`psql`) | echt im Container ausgeführt (Zabbix 7.0.32 aus dem Quellcode, PostgreSQL 16) | auf `zbx01` mit dem installierten Stand wiederholen |
| 02 | `createdb`, `psql` (`schema.sql`, `images.sql`, `data.sql`), `zabbix_server -c … -R …`, `zabbix_agentd -t`, Anmeldung und `user.update` über die API; Paketinstallation (Text) | Programme echt; **Paketinstallation nicht ausgeführt** (Paketnamen nicht bestätigt) | Pakete von zabbix.com auf `zbx01` installieren und Schritte vergleichen |
| 03 | API: `hostgroup.create`, `host.create`, `item.create`, `trigger.create`, `problem.get`; Ereignisse in der Datenbank | echt im Container ausgeführt | mit Frontend im Browser wiederholen (Menünamen nicht bestätigt) |
| 04 | API: `template.create`, `usermacro.create`, Vorverarbeitung, aktive Prüfung, `zabbix_sender`; Windows-Agent (Text) | echt ausgeführt; **Windows-Agent nicht ausgeführt** | Windows-Agent auf `win01` installieren (Dienstname und Pfad prüfen) |
| 05 | `snmpd`, `snmpget`, `snmpwalk`; SNMP-Schnittstelle und SNMP-Items über die API | echt ausgeführt; **SNMPv3 und Traps nicht getestet** | SNMP auf `lin01` und einem Netzgerät wiederholen |
| 06 | Entdeckungsskript (Bash, JSON), `discoveryrule.create`, Prototypen | echt ausgeführt | mit Dateisystem- und Netzwerkschnittstellen-Entdeckung wiederholen |
| 07 | Medientyp „Skript“, Aktion, Wartungsfenster (`maintenance.create`), `dashboard.create` | echt ausgeführt; **E-Mail und Browser-Darstellung nicht getestet** | E-Mail-Versand und Dashboard im Browser prüfen |
| 08 | interne Items, `housekeeping.update`, `pg_dump`, `pg_restore`/`psql`, zweiter Server auf der Kopie | echt im Container ausgeführt; kein systemd | Dienste unter systemd auf `zbx01` einrichten; Neustart testen |
