"""GELF-Modell (Graylog Extended Log Format, Version 1.1) für die Übungen. Aufbau nach Fachwissen; NICHT gegen die GELF-Spezifikation und NICHT gegen Graylog geprüft."""
import gzip, json, os, zlib

def pruefe(m):
    """Gibt eine Liste von Fehlern zurück (leer = gültig)."""
    f = []
    if m.get("version") != "1.1": f.append('version muss "1.1" sein')
    if not isinstance(m.get("host"), str) or not m.get("host"): f.append("host fehlt oder ist leer")
    if not isinstance(m.get("short_message"), str) or not m.get("short_message"): f.append("short_message fehlt oder ist leer")
    if "level" in m and not (isinstance(m["level"], int) and 0 <= m["level"] <= 7): f.append("level muss eine Zahl von 0 bis 7 sein")
    if "timestamp" in m and not isinstance(m["timestamp"], (int, float)): f.append("timestamp muss eine Zahl sein (Sekunden seit 1970)")
    for k, v in m.items():
        if k in ("version", "host", "short_message", "full_message", "timestamp", "level"): continue
        if not k.startswith("_"): f.append(f'Zusatzfeld "{k}" muss mit Unterstrich beginnen')
        elif k == "_id": f.append('Zusatzfeld "_id" ist nicht erlaubt')
        elif not isinstance(v, (str, int, float)): f.append(f'Zusatzfeld "{k}" darf nur Text oder Zahl enthalten')
    return f

def kodiere(m, kompression=None):
    b = json.dumps(m, ensure_ascii=False).encode("utf-8")
    return gzip.compress(b) if kompression == "gzip" else zlib.compress(b) if kompression == "zlib" else b

def chunks(daten, groesse=1420):
    """Zerlegt ein Datagramm in Teile: Kennung 0x1e 0x0f, 8 Byte Nachrichten-ID, Nummer, Anzahl (höchstens 128 Teile)."""
    teile = [daten[i:i + groesse] for i in range(0, len(daten), groesse)]
    if len(teile) > 128: raise ValueError("mehr als 128 Teile")
    mid = os.urandom(8)
    return [b"\x1e\x0f" + mid + bytes([n, len(teile)]) + t for n, t in enumerate(teile)]

def dekodiere(b):
    if b[:2] == b"\x1f\x8b": b = gzip.decompress(b)
    elif b[:1] == b"\x78": b = zlib.decompress(b)
    return json.loads(b.decode("utf-8"))

class Sammler:
    """Setzt Teile wieder zusammen; unvollständige Nachrichten bleiben liegen."""
    def __init__(self): self.offen = {}
    def paket(self, p):
        if p[:2] != b"\x1e\x0f": return dekodiere(p)
        mid, n, anz = p[2:10], p[10], p[11]
        d = self.offen.setdefault(mid, {"anz": anz, "teile": {}}); d["teile"][n] = p[12:]
        if len(d["teile"]) == anz:
            del self.offen[mid]; return dekodiere(b"".join(d["teile"][i] for i in range(anz)))
        return None
