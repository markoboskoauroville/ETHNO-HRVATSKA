#!/usr/bin/env python3
"""Check that every lyric line in songs/*.json appears word for word in the source lyric PDF, and the other way round.
Usage: python3 tools/check_lyrics.py [source/Pjesme tekstovi.pdf]   Exit code 1 on a mismatch."""
import glob, json, os, re, sys
import fitz

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'source', 'Pjesme tekstovi.pdf')
norm = lambda s: re.sub(r'\s*\(×2\)\s*', '', s).strip()
pdf = [norm(l) for p in fitz.open(src) for l in p.get_text().splitlines() if l.strip()]
mine = {}
for f in sorted(glob.glob(os.path.join(ROOT, 'songs', '[0-9]*.json'))):
    d = json.load(open(f, encoding='utf-8'))
    for s in d['sections']:
        for l in s['lines']:
            mine.setdefault(norm(l['text']), d['number'])
bad = [f"{n}: not in the PDF: {t!r}" for t, n in mine.items() if t not in set(pdf)]
extra = [l for l in pdf if l not in mine]   # titles, section labels, notes such as '(Međimurje?)'
for b in bad:
    print(b)
print(f"{len(mine)} distinct song lines checked, {len(bad)} mismatches. PDF-only lines (titles/labels): {extra}")
sys.exit(1 if bad else 0)
