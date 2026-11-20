#!/usr/bin/env bash
# Modul 6: Abhängigkeiten. MODELL (prtg.py): Elternsensor fällt aus, Kinder werden pausiert statt gemeldet. Das Verhalten von PRTG wurde nicht geprüft.
. "$(dirname "$0")/../lab.sh"
export PYTHONPATH="$HERE"
step "1. Baum: Internet-Router -> Firewall -> Switch -> zwei Server -> deren Dienste"
python3 - <<'PY'
import prtg
b = {"Router": None, "Firewall": "Router", "Switch": "Firewall", "srv01": "Switch", "srv02": "Switch", "HTTP srv01": "srv01", "SQL srv02": "srv02"}
def zeige(k, e=0):
    print("  " + "  " * e + k)
    for x, p in b.items():
        if p == k: zeige(x, e + 1)
zeige("Router")
print("  Zyklus vorhanden:", prtg.zyklus(b))
PY
step "2. Ausfall des Switches: gemeldet wird nur der Switch, alles darunter ist pausiert"
python3 - <<'PY'
import prtg
b = {"Router": None, "Firewall": "Router", "Switch": "Firewall", "srv01": "Switch", "srv02": "Switch", "HTTP srv01": "srv01", "SQL srv02": "srv02"}
g, p = prtg.abhaengigkeit(b, {"Switch", "srv01", "srv02", "HTTP srv01", "SQL srv02"})
print("  gemeldet Down:", g); print("  pausiert     :", p)
g0 = sorted(["Switch", "srv01", "srv02", "HTTP srv01", "SQL srv02"])
print(f"  ohne Abhängigkeiten: {len(g0)} Meldungen; mit: {len(g)} Meldung")
PY
step "3. Nur ein Dienst fällt aus (HTTP srv01): nichts wird pausiert"
python3 - <<'PY'
import prtg
b = {"Router": None, "Firewall": "Router", "Switch": "Firewall", "srv01": "Switch", "srv02": "Switch", "HTTP srv01": "srv01", "SQL srv02": "srv02"}
print("  ", prtg.abhaengigkeit(b, {"HTTP srv01"}))
PY
step "4. Zyklus: A hängt von B ab und B von A - wird erkannt (in PRTG verhindern, nicht bestätigt, wie es sich verhält)"
python3 - <<'PY'
import prtg
print("  Zyklus A<->B:", prtg.zyklus({"A": "B", "B": "A"}), "| Kette A->B->C:", prtg.zyklus({"A": "B", "B": "C", "C": None}))
PY
step "5. Falle: der Elternsensor passt nicht zur Wirklichkeit (srv01 hängt in PRTG an der Firewall, ist aber noch über einen zweiten Weg erreichbar)"
python3 - <<'PY'
import prtg
b = {"Firewall": None, "srv01": "Firewall"}
print("  Firewall fällt aus, srv01 ist über einen zweiten Weg erreichbar -> Modell sagt:", prtg.abhaengigkeit(b, {"Firewall"}))
print("  Folge: ein echter Ausfall von srv01 bleibt unsichtbar, solange die Firewall Down ist (pausiert = nicht geprüft)")
PY
