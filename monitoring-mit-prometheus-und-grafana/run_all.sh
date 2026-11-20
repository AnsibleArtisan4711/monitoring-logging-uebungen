#!/usr/bin/env bash
# Führt alle Modulskripte aus und schreibt die Ausgaben nach NN-name/beispiele/SKRIPT.ausgabe.txt.
# Dateien unter /tmp/p18, Ports 19090 (Prometheus), 19093 (Alertmanager), 19095 (Webhook), 19100 (node_exporter), siehe README.
cd "$(dirname "$0")" || exit 1
for d in [0-9][0-9]-*/; do
  for s in "$d"*.sh; do
    [ -f "$s" ] || continue
    b=$(basename "$s" .sh); mkdir -p "${d}beispiele"
    bash "$s" 2>&1 | grep -v '^Terminated$' > "${d}beispiele/$b.ausgabe.txt"
    echo "$s -> $(wc -l < "${d}beispiele/$b.ausgabe.txt") Zeilen"
  done
done
