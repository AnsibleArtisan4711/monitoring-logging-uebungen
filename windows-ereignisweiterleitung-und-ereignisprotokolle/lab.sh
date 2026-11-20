#!/usr/bin/env bash
# Gemeinsame Hilfen der Übungsreihe (P66). Es gibt KEIN Windows im Test: Die Ereignisse sind erfundene Beispieldaten im Format von Windows-Ereignissen (XML).
W=/tmp/p66; HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
step() { echo; echo "## $*"; }
cmd() { echo "\$ $*"; "$@" 2>&1; return $?; }
lab_up() { lab_down >/dev/null 2>&1; mkdir -p "$W"; python3 "$HERE/gen_events.py" "$W/events.xml"; }
lab_down() { rm -rf "$W"; }
trap 'lab_down >/dev/null 2>&1' EXIT
