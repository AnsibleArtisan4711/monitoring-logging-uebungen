#!/usr/bin/env bash
# Modul 5: Karten und Berichte. Echt: Auswertung erfundener Messdaten mit Python/awk, SVG-Karte mit xmllint geprüft. Die Berichts- und Kartenfunktion von PRTG selbst wurde NICHT ausgeführt.
. "$(dirname "$0")/../lab.sh"
lab_up
export PYTHONPATH="$HERE"
python3 - <<'PY'
# erfundene Ausfallliste einer Woche (Sekunden Down je Sensor); feste Werte, keine Zufallszahlen
w = open("/tmp/p20/ausfaelle.csv", "w")
w.write("sensor,sekunden_down,ausfaelle\nPing srv01,0,0\nHTTP srv01,2640,3\nPing fw01,300,1\nPing sw01,0,0\nSNMP srv02,10800,2\n"); w.close()
PY
step "1. Verfügbarkeit je Sensor für eine Woche (604800 s) aus der erfundenen Ausfallliste"
python3 - <<'PY'
import csv, prtg
G = 7 * 86400
for r in csv.DictReader(open("/tmp/p20/ausfaelle.csv")):
    v = prtg.verfuegbarkeit(G, int(r["sekunden_down"]))
    print(f"  {r['sensor']:12s} {v:8.3f} %   Ausfälle {r['ausfaelle']}   mittlere Dauer {int(r['sekunden_down'])//max(int(r['ausfaelle']),1)} s")
PY
step "2. Was 99,9 % in einer Woche bedeutet, und wer die Zielmarke 99,9 % verfehlt"
python3 - <<'PY'
import csv, prtg
G = 7 * 86400
print(f"  99,9 % erlauben {G*0.001:.1f} s Ausfall pro Woche")
print("  verfehlen die Marke:", [r["sensor"] for r in csv.DictReader(open("/tmp/p20/ausfaelle.csv")) if prtg.verfuegbarkeit(G, int(r["sekunden_down"])) < 99.9])
PY
step "3. Bericht als Tabelle (CSV) und als Zeilen, sortiert nach Ausfalldauer"
tail -n +2 "$W/ausfaelle.csv" | sort -t, -k2 -nr | awk -F, '{printf "  %-12s %6d s  %d Ausfälle\n", $1, $2, $3}'
step "4. Karte (Modell): eine SVG mit einem Kästchen je Gerät, Farbe nach Status; mit xmllint auf Wohlgeformtheit geprüft"
python3 - <<'PY'
farbe = {"Up": "#2e9e44", "Warning": "#e0a800", "Down": "#c62828", "Paused": "#8a8a8a"}
geraete = [("fw01", "Up"), ("sw01", "Up"), ("srv01", "Warning"), ("srv02", "Down"), ("srv03", "Paused")]
teile = ['<?xml version="1.0" encoding="UTF-8"?>', '<svg xmlns="http://www.w3.org/2000/svg" width="520" height="90">']
for i, (n, s) in enumerate(geraete):
    teile.append(f'  <rect x="{10+i*100}" y="10" width="90" height="50" fill="{farbe[s]}"/>')
    teile.append(f'  <text x="{20+i*100}" y="40" fill="white" font-size="14">{n}</text>')
teile.append("</svg>"); open("/tmp/p20/karte.svg", "w").write("\n".join(teile) + "\n")
PY
cmd xmllint --noout "$W/karte.svg"; echo "Rückgabewert xmllint: $?"
echo "Kästchen: $(grep -c '<rect' "$W/karte.svg"), davon rot: $(grep -c '#c62828' "$W/karte.svg")"
step "5. Eine kaputte Karte wird erkannt (nicht geschlossenes Tag)"
sed 's#</svg>##' "$W/karte.svg" > "$W/kaputt.svg"; xmllint --noout "$W/kaputt.svg" 2>&1 | head -2 | sed -E "s#/tmp/p20/##"
