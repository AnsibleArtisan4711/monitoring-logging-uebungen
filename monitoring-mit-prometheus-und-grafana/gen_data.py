#!/usr/bin/env python3
"""Erzeugt eine erfundene Messreihe im OpenMetrics-Format (2 Stunden, alle 15 s, drei Hosts plus eine Anwendung).
Alle Werte sind berechnet oder stammen aus einer festen Zufallsfolge (Startwert 42); keine echten Messungen."""
import sys, random
T0, N, STEP = 1793000400, 481, 15
rnd = random.Random(42)
out = []
def meta(name, typ): out.append('# TYPE %s %s' % (name, typ))
def sample(name, labels, value, t):
    l = ','.join('%s="%s"' % kv for kv in labels)
    out.append('%s{%s} %s %d' % (name, l, repr(round(value, 6)) if isinstance(value, float) else value, t))
hosts = {'srv01': dict(busy=0.18, mem=0.45, fill=0), 'srv02': dict(busy=0.35, mem=0.70, fill=1), 'win01': dict(busy=0.25, mem=0.55, fill=0)}
# CPU-Zähler (Linux-Hosts): Sekunden je Modus, 2 Kerne
meta('node_cpu_seconds', 'counter')
for h in ('srv01', 'srv02'):
    p = hosts[h]; acc = {'idle': 0.0, 'user': 0.0, 'system': 0.0}
    for i in range(N):
        t = T0 + i * STEP
        busy = p['busy'] + (0.5 * i / N if h == 'srv02' else 0) + rnd.uniform(-0.03, 0.03)   # srv02 wird langsam ausgelastet
        busy = min(max(busy, 0.01), 0.98)
        acc['user'] += STEP * busy * 0.7; acc['system'] += STEP * busy * 0.3; acc['idle'] += STEP * (1 - busy)
        for m, v in acc.items(): sample('node_cpu_seconds_total', [('cpu', '0'), ('instance', h + ':9100'), ('job', 'node'), ('mode', m)], round(v, 3), t)
meta('node_memory_MemTotal_bytes', 'gauge'); meta('node_memory_MemAvailable_bytes', 'gauge')
for h in ('srv01', 'srv02'):
    p = hosts[h]
    for i in range(N):
        t = T0 + i * STEP; tot = 8 * 1024**3
        used = p['mem'] + (0.20 * i / N if h == 'srv02' else 0) + rnd.uniform(-0.01, 0.01)
        sample('node_memory_MemTotal_bytes', [('instance', h + ':9100'), ('job', 'node')], tot, t)
        sample('node_memory_MemAvailable_bytes', [('instance', h + ':9100'), ('job', 'node')], int(tot * (1 - used)), t)
meta('node_filesystem_size_bytes', 'gauge'); meta('node_filesystem_avail_bytes', 'gauge')
for h in ('srv01', 'srv02'):
    for i in range(N):
        t = T0 + i * STEP; size = 100 * 1024**3
        used = (0.40 + 0.0001 * i) if h == 'srv01' else (0.60 + 0.00045 * i)    # srv02 füllt sich schnell
        lab = [('instance', h + ':9100'), ('job', 'node'), ('mountpoint', '/')]
        sample('node_filesystem_size_bytes', lab, size, t); sample('node_filesystem_avail_bytes', lab, int(size * (1 - used)), t)
# up: srv02 fällt in den letzten 10 Minuten aus, win01 läuft
meta('up', 'gauge')
for h, job, port in (('srv01', 'node', '9100'), ('srv02', 'node', '9100'), ('win01', 'windows', '9182')):
    for i in range(N):
        t = T0 + i * STEP; v = 0 if (h == 'srv02' and i >= N - 41) else 1
        sample('up', [('instance', h + ':' + port), ('job', job)], v, t)
# Windows-Host: freier Platz (windows_exporter-Name)
meta('windows_logical_disk_free_bytes', 'gauge')
for i in range(N):
    t = T0 + i * STEP; sample('windows_logical_disk_free_bytes', [('instance', 'win01:9182'), ('job', 'windows'), ('volume', 'C:')], int(60 * 1024**3 - i * 2_000_000), t)
# Anwendung: Zähler nach Statuscode und Histogramm der Antwortzeit
meta('http_requests', 'counter')
acc = {'200': 0, '404': 0, '500': 0}
for i in range(N):
    t = T0 + i * STEP; err = 6 if i > N - 80 else 0   # Fehlerwelle gegen Ende
    acc['200'] += 120 + rnd.randint(-10, 10); acc['404'] += 3 + rnd.randint(0, 2); acc['500'] += err + rnd.randint(0, 1)
    for c, v in acc.items(): sample('http_requests_total', [('code', c), ('instance', 'app01:8080'), ('job', 'app')], v, t)
meta('http_request_duration_seconds', 'histogram')
bounds = ['0.05', '0.1', '0.25', '0.5', '1', '+Inf']; cum = [0] * 6; tot = 0.0; cnt = 0
for i in range(N):
    t = T0 + i * STEP; slow = (i > N - 80)
    for _ in range(120):
        d = rnd.expovariate(1 / (0.30 if slow else 0.08)); cnt += 1; tot += d
        for k, b in enumerate(bounds[:-1]):
            if d <= float(b): cum[k] += 1
        cum[5] += 1
    for b, v in zip(bounds, cum): sample('http_request_duration_seconds_bucket', [('instance', 'app01:8080'), ('job', 'app'), ('le', b)], v, t)
    sample('http_request_duration_seconds_sum', [('instance', 'app01:8080'), ('job', 'app')], round(tot, 6), t)
    sample('http_request_duration_seconds_count', [('instance', 'app01:8080'), ('job', 'app')], cnt, t)
out.append('# EOF')
open(sys.argv[1], 'w').write('\n'.join(out) + '\n')
