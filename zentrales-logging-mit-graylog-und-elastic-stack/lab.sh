#!/usr/bin/env bash
# Gemeinsame Hilfen der Übungsreihe (P19). Echt: rsyslog 8.2312 (zwei Instanzen auf 127.0.0.1), logger, logrotate, jq, Python 3.
# NICHT ausgeführt: Graylog, Elasticsearch, Logstash, Beats, OpenSearch, MongoDB. Deren Module (3 bis 5) sind Modelle in Python.
# Die Logdaten der Module 5 bis 8 sind erfunden (gen_logs.py, feste Zufallsfolge).
W=/tmp/p19; HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UDPS=15514; TCPS=15515; UDPC=15517
step() { echo; echo "## $*"; }
cmd() { echo "\$ $*"; "$@" 2>&1; return $?; }
waitfor() { for _ in $(seq 1 60); do eval "$1" >/dev/null 2>&1 && return 0; sleep 0.3; done; echo "TIMEOUT $1"; return 1; }
lab_down() { pkill -f "rsyslogd -f $W/" 2>/dev/null; for _ in $(seq 1 20); do pgrep -f "rsyslogd -f $W/" >/dev/null || break; sleep 0.3; done; pkill -9 -f "rsyslogd -f $W/" 2>/dev/null; sleep 0.5; rm -rf "$W"; }
lab_up() { lab_down >/dev/null 2>&1; mkdir -p "$W"; }
trap 'lab_down >/dev/null 2>&1' EXIT
# Zeilenzahl einer Datei (0, wenn sie fehlt)
zl() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
# wartet, bis die Datei mindestens N Zeilen hat
warte_zeilen() { for _ in $(seq 1 80); do [ "$(zl "$1")" -ge "$2" ] && return 0; sleep 0.3; done; echo "TIMEOUT $1 < $2 Zeilen"; return 1; }
