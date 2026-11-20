#!/usr/bin/env bash
# Modul 1: Logquellen und Formate. Echt: rsyslog nimmt Meldungen per UDP an (logger), schreibt die Rohzeilen; Python zerlegt sie.
. "$(dirname "$0")/../lab.sh"
lab_up; mkdir -p "$W/s"
cat > "$W/s.conf" <<C
global(localHostname="log01" workDirectory="$W/s")
module(load="imudp")
input(type="imudp" address="127.0.0.1" port="$UDPS")
template(name="roh" type="string" string="%rawmsg%\n")
template(name="felder" type="string" string="PRI=%pri% facility=%syslogfacility%(%syslogfacility-text%) severity=%syslogseverity%(%syslogseverity-text%) host=%hostname% programm=%programname% msg=%msg%\n")
*.* action(type="omfile" file="$W/s/roh.log" template="roh")
*.* action(type="omfile" file="$W/s/felder.log" template="felder")
C
step "1. Konfiguration prüfen (rsyslogd -N1) und Server starten"
rsyslogd -N1 -f "$W/s.conf" 2>&1 | sed -E 's/^rsyslogd: version [0-9.]+, config validation run.*/rsyslogd: Konfigurationsprüfung/' | head -3
rsyslogd -f "$W/s.conf" -i "$W/s.pid" -n >"$W/s.out" 2>&1 &
waitfor "[ -s $W/s.pid ]"; sleep 1
step "2. Meldungen senden: RFC 3164 (alt) und RFC 5424 (neu), verschiedene Facility und Severity"
logger -n 127.0.0.1 -P $UDPS -d --rfc3164 -t webapp -p local4.warning "Platte fast voll"
logger -n 127.0.0.1 -P $UDPS -d --rfc5424 -t sshd -p auth.err "Failed password for ben from 10.18.0.99"
logger -n 127.0.0.1 -P $UDPS -d --rfc5424 -t kernel -p kern.crit "Out of memory: Killed process 4711"
logger -n 127.0.0.1 -P $UDPS -d --rfc3164 -t cron -p cron.info "job backup ok"
warte_zeilen "$W/s/roh.log" 4
step "3. Rohzeilen auf dem Draht (Zeitstempel und Rechnername werden zur Anzeige ersetzt)"
python3 - "$W/s/roh.log" <<'PY'
import re, sys
for z in sorted(open(sys.argv[1]).read().splitlines()):
    z = re.sub(r'\d{4}-\d\d-\d\dT[0-9:.+-]+', '<ZEIT>', z)
    z = re.sub(r'^(<\d+>)[A-Z][a-z]{2} [ 0-9]\d [0-9:]{8}', r'\1<ZEIT>', z)
    z = re.sub(r'(<ZEIT>) \S+ ', r'\1 <HOST> ', z)
    print(z)
PY
step "4. Von rsyslog zerlegte Felder (Facility, Severity, Programm, Text)"
sed -E 's/host=[^ ]+/host=<HOST>/' "$W/s/felder.log" | sort
step "5. Priorität (PRI) = Facility × 8 + Severity, mit Python nachgerechnet"
python3 - "$W/s/roh.log" <<'PY'
import re, sys
fac = ['kern','user','mail','daemon','auth','syslog','lpr','news','uucp','cron','authpriv','ftp','ntp','audit','alert','clock','local0','local1','local2','local3','local4','local5','local6','local7']
sev = ['emerg','alert','crit','err','warning','notice','info','debug']
for z in sorted(open(sys.argv[1]).read().splitlines()):
    m = re.match(r'<(\d+)>(\d?)', z)
    pri = int(m.group(1)); f, s = divmod(pri, 8)
    fmt = 'RFC 5424' if m.group(2) == '1' else 'RFC 3164'
    print(f"  PRI {pri:3d} = {f:2d} × 8 + {s}  -> {fac[f]:8s} {sev[s]:8s} ({fmt})")
PY
step "6. Fehlerbild: fehlerhafte Konfiguration wird von rsyslogd -N1 erkannt"
printf 'module(load="gibtsnicht")\n*.* action(type="omfile" file="/tmp/x.log"\n' > "$W/kaputt.conf"
rsyslogd -N1 -f "$W/kaputt.conf" 2>&1 | grep -E "error|could not|invalid|End of config" | sed -E 's/rsyslogd: version [0-9.]+, //; s/\[v[0-9.]+[^]]*\]//; s/ \(e\.g\..*//' | cut -c1-150 | head -4
echo "Rückgabecode: ${PIPESTATUS[0]}"
step "7. Windows-Ereignisprotokoll und journald (NICHT ausgeführt)"
cat <<'T'
  Windows-Ereignisse (zum Beispiel 4625) liegen im Ereignisprotokoll und werden von einem Agenten gelesen; in dieser Reihe nur als Modell (Modul 3).
  journald: In diesem Container läuft kein systemd; `journalctl` wurde nicht getestet. Auf Linux-VMs mit systemd liefert es dieselben Meldungen.
T
