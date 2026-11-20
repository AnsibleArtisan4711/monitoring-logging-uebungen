#!/usr/bin/env bash
# Modul 2: Erfassung und Weiterleitung mit zwei echten rsyslog-Instanzen: Client (lin01) leitet per TCP an den Server (log01) weiter.
. "$(dirname "$0")/../lab.sh"
lab_up; mkdir -p "$W/s" "$W/c"; : > "$W/c/app.log"
cat > "$W/s.conf" <<C
global(localHostname="log01" workDirectory="$W/s")
module(load="imtcp")
input(type="imtcp" address="127.0.0.1" port="$TCPS")
template(name="json" type="list") {
  constant(value="{\"host\":\"") property(name="hostname")
  constant(value="\",\"programm\":\"") property(name="programname")
  constant(value="\",\"severity\":\"") property(name="syslogseverity-text")
  constant(value="\",\"facility\":\"") property(name="syslogfacility-text")
  constant(value="\",\"nachricht\":\"") property(name="msg" format="json")
  constant(value="\"}\n")
}
*.* action(type="omfile" file="$W/s/alle.json" template="json")
C
cat > "$W/c.conf" <<C
global(localHostname="lin01" workDirectory="$W/c")
module(load="imudp")
input(type="imudp" address="127.0.0.1" port="$UDPC" ruleset="weiter")
module(load="imfile")
input(type="imfile" file="$W/c/app.log" tag="app:" severity="warning" facility="local5" ruleset="weiter")
ruleset(name="weiter") {
  # nur Meldungen ab Schweregrad "warning" (Zahl 4 und kleiner) werden weitergeleitet
  if \$syslogseverity <= 4 then {
    action(type="omfwd" target="127.0.0.1" port="$TCPS" protocol="tcp" action.resumeRetryCount="-1" action.resumeInterval="1"
           queue.type="LinkedList" queue.size="1000" queue.filename="fwd" queue.maxdiskspace="10m" queue.saveonshutdown="on")
  }
}
C
step "1. Konfigurationen prüfen"
rsyslogd -N1 -f "$W/s.conf" 2>&1 | tail -1; rsyslogd -N1 -f "$W/c.conf" 2>&1 | tail -1
start_s() { rsyslogd -f "$W/s.conf" -i "$W/s.pid" -n >"$W/s.out" 2>&1 & waitfor "[ -s $W/s.pid ]"; sleep 1; }
start_c() { rsyslogd -f "$W/c.conf" -i "$W/c.pid" -n >"$W/c.out" 2>&1 & waitfor "[ -s $W/c.pid ]"; sleep 1; }
start_s; start_c
step "2. Meldungen über UDP an den Client: Filter lässt nur warning und schwerer durch"
logger -n 127.0.0.1 -P $UDPC -d --rfc3164 -t webapp -p local4.err     "Datenbank nicht erreichbar"
logger -n 127.0.0.1 -P $UDPC -d --rfc3164 -t webapp -p local4.info    "Seite aufgerufen"
logger -n 127.0.0.1 -P $UDPC -d --rfc3164 -t webapp -p local4.warning "Antwortzeit hoch"
logger -n 127.0.0.1 -P $UDPC -d --rfc3164 -t webapp -p local4.debug   "Cache-Treffer"
warte_zeilen "$W/s/alle.json" 2; sleep 1
echo "Am Server angekommen: $(zl "$W/s/alle.json") von 4 gesendeten Meldungen (info und debug wurden gefiltert)"
jq -c '{programm,severity,nachricht:(.nachricht|sub("^ +";""))}' "$W/s/alle.json" | sort
step "3. Dateiüberwachung (imfile): Zeilen einer Anwendungsdatei werden gelesen und weitergeleitet"
before=$(zl "$W/s/alle.json")
printf 'Zeile A der Anwendung\nZeile B der Anwendung\n' >> "$W/c/app.log"
warte_zeilen "$W/s/alle.json" $((before+2)); sleep 1
jq -r 'select(.programm=="app")|"\(.programm) \(.severity) \(.facility): \(.nachricht|sub("^ +";""))"' "$W/s/alle.json" | sort
step "4. Server fällt aus: der Client puffert in der Warteschlange und liefert nach dem Neustart nach"
kill $(cat "$W/s.pid"); for _ in $(seq 1 20); do pgrep -f "rsyslogd -f $W/s.conf" >/dev/null || break; sleep 0.3; done
before=$(zl "$W/s/alle.json")
logger -n 127.0.0.1 -P $UDPC -d --rfc3164 -t webapp -p local4.err "Meldung 1 während des Ausfalls"
logger -n 127.0.0.1 -P $UDPC -d --rfc3164 -t webapp -p local4.err "Meldung 2 während des Ausfalls"
sleep 3; echo "Zeilen am Server während des Ausfalls: $(( $(zl "$W/s/alle.json") - before )) neu"
start_s; warte_zeilen "$W/s/alle.json" $((before+2)) 
echo "Nach dem Neustart des Servers neu angekommen: $(( $(zl "$W/s/alle.json") - before ))"
jq -r 'select(.nachricht|test("Ausfalls"))|.nachricht|sub("^ +";"")' "$W/s/alle.json" | sort
step "5. Fehlerbild: falscher Zielport; nichts kommt an, der Client meldet es im Protokoll"
sed "s/port=\"$TCPS\" protocol/port=\"15999\" protocol/" "$W/c.conf" > "$W/c2.conf"; kill $(cat "$W/c.pid"); sleep 1
rsyslogd -f "$W/c2.conf" -i "$W/c2.pid" -n >"$W/c2.out" 2>&1 & waitfor "[ -s $W/c2.pid ]"; sleep 1
before=$(zl "$W/s/alle.json"); logger -n 127.0.0.1 -P $UDPC -d --rfc3164 -t webapp -p local4.err "geht nicht durch"; sleep 3
echo "Neu am Server: $(( $(zl "$W/s/alle.json") - before ))"
echo "Hinweis in der Ausgabe des Clients: $(grep -ciE 'connection refused|suspended|cannot connect|could not connect' "$W/c2.out") Zeile(n) mit Verbindungsproblem"
kill $(cat "$W/c2.pid") 2>/dev/null
