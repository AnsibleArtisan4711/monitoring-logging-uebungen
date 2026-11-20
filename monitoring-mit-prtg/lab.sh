#!/usr/bin/env bash
# Gemeinsame Hilfen der Übungsreihe (P20). PRTG selbst läuft hier NICHT (nur Windows). Echt: snmpd 5.9.4 (net-snmp) auf 127.0.0.1,
# ein HTTP-Server in Python, TCP-Prüfungen, Skripte für eigene Sensoren, xmllint, jq. Das Verhalten von PRTG (Status, Benachrichtigung,
# Abhängigkeiten, Lizenz) ist ein MODELL in Python (prtg.py) nach den Angaben im Lehrplan - nicht gegen PRTG geprüft.
W=/tmp/p20; HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNMPP=11162; HTTPP=18201; HOOKP=18202
step() { echo; echo "## $*"; }
cmd() { echo "\$ $*"; "$@" 2>&1; return $?; }
waitfor() { for _ in $(seq 1 60); do eval "$1" >/dev/null 2>&1 && return 0; sleep 0.3; done; echo "TIMEOUT $1"; return 1; }
lab_down() { pkill -f "snmpd .*$W/" 2>/dev/null; pkill -f "prtg_dienst.py $W" 2>/dev/null; for _ in $(seq 1 20); do pgrep -f "$W/" >/dev/null || break; sleep 0.3; done; pkill -9 -f "$W/" 2>/dev/null; sleep 0.3; rm -rf "$W"; }
lab_up() { lab_down >/dev/null 2>&1; mkdir -p "$W"; }
trap 'lab_down >/dev/null 2>&1' EXIT
