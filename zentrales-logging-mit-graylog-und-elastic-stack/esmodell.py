"""Kleines Modell einer Suchmaschine im Stil von Elasticsearch (invertierter Index, Abfragesprache als JSON, Aggregationen).
NICHT Elasticsearch: Bewertung (Score) ist hier nur die Zahl der passenden Wörter, Verhalten und Namen sind Fachwissen und nicht gegen Elasticsearch geprüft."""
import re, collections
from datetime import datetime

def analysiere(t): return re.findall(r"[a-z0-9]+", str(t).lower())

class Index:
    def __init__(self, mapping): self.mapping = mapping; self.docs = []; self.inv = {}
    def add(self, d):
        i = len(self.docs); self.docs.append(d)
        for f, v in d.items():
            if self.mapping.get(f) == "text":
                for w in set(analysiere(v)): self.inv.setdefault((f, w), set()).add(i)
            elif self.mapping.get(f) in ("keyword", "long"): self.inv.setdefault((f, str(v)), set()).add(i)
    def _wert(self, f, v):
        t = self.mapping.get(f)
        return float(v) if t == "long" else v
    def _treffer(self, q, alle):
        (k, a), = q.items()
        if k == "match_all": return set(alle)
        if k == "term":
            (f, v), = a.items(); v = v["value"] if isinstance(v, dict) else v
            return set(self.inv.get((f, str(v)), set()))
        if k == "terms":
            (f, vs), = a.items(); r = set()
            for v in vs: r |= self.inv.get((f, str(v)), set())
            return r
        if k == "match":
            (f, v), = a.items(); v = v["query"] if isinstance(v, dict) else v; op = a[f].get("operator", "or") if isinstance(a[f], dict) else "or"
            ms = [self.inv.get((f, w), set()) for w in analysiere(v)]
            if not ms: return set()
            return set.intersection(*ms) if op == "and" else set.union(*ms)
        if k == "range":
            (f, b), = a.items(); r = set()
            for i in alle:
                if f not in self.docs[i]: continue
                x = self._wert(f, self.docs[i][f]); ok = True
                for op, lim in b.items():
                    lim = self._wert(f, lim)
                    ok &= {"gte": x >= lim, "gt": x > lim, "lte": x <= lim, "lt": x < lim}[op]
                if ok: r.add(i)
            return r
        if k == "exists": return {i for i in alle if a["field"] in self.docs[i]}
        if k == "bool":
            r = set(alle)
            for q2 in a.get("must", []) + a.get("filter", []): r &= self._treffer(q2, alle)
            for q2 in a.get("must_not", []): r -= self._treffer(q2, alle)
            sh = a.get("should", [])
            if sh:
                msm = a.get("minimum_should_match", 0 if (a.get("must") or a.get("filter")) else 1)
                zaehl = collections.Counter(i for q2 in sh for i in self._treffer(q2, alle))
                r = {i for i in r if zaehl[i] >= msm}
            return r
        raise ValueError("unbekannte Abfrage " + k)
    def suche(self, body, size=3):
        alle = range(len(self.docs)); ids = sorted(self._treffer(body.get("query", {"match_all": {}}), alle))
        erg = {"gesamt": len(ids), "treffer": [self.docs[i] for i in ids[:size]]}
        if "aggs" in body: erg["aggs"] = {n: self._agg(a, ids) for n, a in body["aggs"].items()}
        return erg
    def _agg(self, a, ids):
        (t, p), = [(k, v) for k, v in a.items() if k != "aggs"]
        werte = [self.docs[i][p["field"]] for i in ids if p["field"] in self.docs[i]]
        if t == "terms": return [{"key": k, "doc_count": c} for k, c in collections.Counter(werte).most_common(p.get("size", 10))]
        if t == "avg": return {"value": round(sum(werte) / len(werte), 1) if werte else None}
        if t == "max": return {"value": max(werte) if werte else None}
        if t == "value_count": return {"value": len(werte)}
        if t == "date_histogram":     # nur Intervall 1h
            c = collections.Counter(datetime.fromisoformat(w).strftime("%Y-%m-%dT%H:00") for w in werte)
            return [{"key": k, "doc_count": c[k]} for k in sorted(c)]
        raise ValueError("unbekannte Aggregation " + t)
