#!/usr/bin/env python3
"""Convert songs/src/*.cho (ChordPro-like authoring text) to songs/*.json (schema ethno-song/1).

Line syntax:   [Am]lyric with [C]chords || English translation || ×2
  [X]  chord from the song's chord_source (confirmed)
  [~X] chord inferred by analogy (not confirmed)
  [^X] chord taken from the audio analysis on a board-sourced song (not confirmed)
A chord at the very end of a line ("ja. [Am]") gets at_char == len(text): it sounds after the last word.
Directives: {key: value}; repeated keys (arr, note, evidence, uncertain, image, play) become lists.
Rhythm (official notation, MPA Academy conventions, never private shorthand): {rhythm: Name} plus
  {rhythm_meter: 2/4} {rhythm_grouping: 3+3+2} {rhythm_cell: 16} (note value of one cell: 16, 8 or 4)
  {rhythm_cells: D - - T - - T -} (D Dum, T Tak, K Ka, P Pa, - ghost note / touch, . silence)
  {rhythm_tempo: ♩ ≈ 95} {rhythm_instrument: ...} {rhythm_mpa: ...} {rhythm_practice: D - - P - - P -}
  {rhythm_confidence: confirmed by recording | to be confirmed by the professor} {rhythm_evidence: ...}
  -> one `rhythm` object (name, meter, grouping, cell, tempo, cells, syllables, events, ...).
Melody: {melody_info: label=...; section=1; lines=1-2; clef=treble|treble8; fifths=1; half_flats=E; time=2/4;
  grouping=2+3; tempo=♩ ≈ 100; status=draft|not_transcribed; confidence=...; source=...}
  and one {melody: ...} per staff system, tokens separated by spaces:
  [Chord]PITCH:LEN[:syllable]   PITCH = E4, F#4, Bb3, Ed4 (half-flat), Bn4 (natural), R (rest); LEN in sixteenths
  (1 = 16th, 2 = 8th, 3 = dotted 8th, 4 = quarter, 6 = dotted quarter, 8 = half, 12 = dotted half, 16 = whole);
  a syllable ending in '-' is followed by a hyphen; '~' before PITCH ties the note to the previous one; '|' is a
  bar line, checked against the time signature.
Usage: python3 tools/cho2json.py [songs/src/01-x.cho ...]   (default: all)
"""
import glob, json, os, re, sys, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LISTS = {'arr': 'arrangement', 'note': 'notes', 'evidence': 'evidence', 'uncertain': 'uncertain', 'image': 'images', 'play': 'play'}
SCALARS = ['number', 'slug', 'title', 'subtitle', 'language', 'key', 'tempo', 'rhythm', 'scale', 'confidence', 'chord_source', 'audio']
CHORD = re.compile(r'\[([~^]?)([^\]]+)\]')
RHYTHM_KEYS = ['rhythm_meter', 'rhythm_grouping', 'rhythm_cell', 'rhythm_cells', 'rhythm_tempo', 'rhythm_instrument',
               'rhythm_mpa', 'rhythm_practice', 'rhythm_confidence', 'rhythm_evidence']
SYLLABLE = {'D': 'DUM', 'T': 'TAK', 'K': 'KA', 'P': 'PA', '-': '–', '.': ''}
TOKEN = re.compile(r'^(?:\[([^\]]+)\])?(~)?([A-Ga-g][#bdn]?\d|R):(\d+)(?::(.*))?$')


def build_rhythm(name, d, path):
    cells = d['rhythm_cells'].split()
    cell = int(d.get('rhythm_cell', 16))
    quarters = 4 / cell                     # length of one cell in quarter notes
    events = []
    for i, c in enumerate(cells):
        if c not in SYLLABLE:
            raise SystemExit(f'{path}: unknown rhythm cell {c!r}')
        events.append({'beat': round(1 + i * quarters, 4), 'value': f'1/{cell}', 'stroke': '' if c == '.' else c,
                       'syllable': SYLLABLE[c], 'accent': c in 'DTKP'})
    n, den = (int(v) for v in d['rhythm_meter'].split('/'))
    if abs(len(cells) * quarters - n * 4 / den) > 1e-6:
        raise SystemExit(f'{path}: {len(cells)} cells of 1/{cell} do not fill {d["rhythm_meter"]}')
    r = {'name': name, 'instrument': d.get('rhythm_instrument', 'Frame drum (bendir, daf, riq)'),
         'meter': d['rhythm_meter'], 'grouping': d.get('rhythm_grouping', ''), 'cell': cell,
         'tempo': d.get('rhythm_tempo', ''), 'cells': ['' if c == '.' else c for c in cells],
         'syllables': [SYLLABLE[c] for c in cells], 'events': events}
    for k in ('mpa', 'practice', 'confidence', 'evidence'):
        if d.get('rhythm_' + k):
            r[k] = d['rhythm_' + k]
    return r


def build_melody(info, systems, path):
    m = {}
    for part in info.split(';'):
        if '=' in part:
            k, v = part.split('=', 1)
            m[k.strip()] = v.strip()
    blen = None
    if m.get('time'):
        n, den = (int(v) for v in m['time'].split('/'))
        blen = n * 16 // den
    out = {'status': m.get('status', 'draft'), 'label': m.get('label', ''), 'section': m.get('section', ''),
           'lines': m.get('lines', ''), 'clef': m.get('clef', 'treble'),
           'key_signature': {'fifths': int(m.get('fifths', 0)),
                             'half_flats': [x for x in m.get('half_flats', '').replace(',', ' ').split() if x]},
           'time': m.get('time', '4/4'), 'grouping': m.get('grouping', ''), 'tempo': m.get('tempo', ''),
           'confidence': m.get('confidence', ''), 'source': m.get('source', ''), 'systems': []}
    pos = 0
    for line in systems:
        notes = []
        for tok in line.split():
            if tok == '|':
                if blen and pos % blen:
                    raise SystemExit(f'{path}: melody bar line at {pos} sixteenths is not on a bar of {m["time"]}')
                continue
            t = TOKEN.match(tok)
            if not t:
                raise SystemExit(f'{path}: bad melody token {tok!r}')
            chord, tie, pitch, ln, syl = t.groups()
            note = {'pitch': pitch if pitch == 'R' else pitch[0].upper() + pitch[1:], 'len': int(ln),
                    'syllable': (syl or '').replace('_', ' ')}
            if chord:
                note['chord'] = chord
            if tie:
                note['tie'] = True
            notes.append(note)
            pos += int(ln)
        out['systems'].append(notes)
    if blen and pos % blen:
        raise SystemExit(f'{path}: melody length {pos} sixteenths is not a whole number of bars of {m["time"]}')
    return out


def parse_line(raw, default_source):
    parts = [p.strip() for p in raw.split('||')]
    lyric = parts[0]
    translation = parts[1] if len(parts) > 1 else ''
    repeat = parts[2] if len(parts) > 2 and parts[2] else None
    text, chords, pos = '', [], 0
    for m in CHORD.finditer(lyric):
        text += lyric[pos:m.start()]
        mark, name = m.group(1), m.group(2).strip()
        source = {'~': 'inferred', '^': 'audio'}.get(mark, default_source)
        chords.append({'at_char': len(text), 'chord': name, 'source': source, 'confirmed': mark == ''})
        pos = m.end()
    text += lyric[pos:]
    stripped = text.rstrip()
    for c in chords:
        c['at_char'] = min(c['at_char'], len(stripped))
    return {'text': unicodedata.normalize('NFC', stripped), 'translation': translation, 'repeat': repeat, 'chords': chords}


def convert(path):
    song = {'schema': 'ethno-song/1'}
    for k in LISTS.values():
        song[k] = []
    sections, cur = [], None
    rhythm_d, mel_info, mel_systems = {}, None, []
    for raw in open(path, encoding='utf-8').read().splitlines():
        line = raw.strip()
        if not line:
            continue
        m = re.fullmatch(r'\{(\w+):\s*(.*)\}', line)
        if m:
            k, v = m.group(1), m.group(2).strip()
            if k == 'section':
                cur = {'name': v, 'lines': []}
                sections.append(cur)
            elif k in RHYTHM_KEYS:
                rhythm_d[k] = v
            elif k == 'melody_info':
                mel_info = v
            elif k == 'melody':
                mel_systems.append(v)
            elif k in LISTS:
                if k == 'play':
                    label, _, chords = v.partition('||')
                    song['play'].append({'label': label.strip(), 'chords': chords.strip()})
                else:
                    song[LISTS[k]].append(v)
            elif k in SCALARS:
                song[k] = v
            else:
                raise SystemExit(f'{path}: unknown directive {k}')
            continue
        if cur is None:
            raise SystemExit(f'{path}: lyric line before any section: {line}')
        cur['lines'].append(parse_line(line, song.get('chord_source', 'board')))
    song['sections'] = sections
    if rhythm_d:
        song['rhythm'] = build_rhythm(song.get('rhythm', ''), rhythm_d, path)
    if mel_info is not None:
        song['melody'] = build_melody(mel_info, mel_systems, path)
    song['sources'] = {'lyrics': 'Pjesme tekstovi.pdf (21.11.2026)', 'images': song.pop('images'), 'audio': song.pop('audio', None)}
    order = ['schema', 'number', 'slug', 'title', 'subtitle', 'language', 'key', 'tempo', 'rhythm', 'melody', 'scale', 'confidence',
             'chord_source', 'play', 'sections', 'arrangement', 'notes', 'evidence', 'uncertain', 'sources']
    return {k: song[k] for k in order if k in song}


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, 'songs', 'src', '*.cho')))
    for f in files:
        song = convert(f)
        out = os.path.join(ROOT, 'songs', f"{song['number']}-{song['slug']}.json")
        with open(out, 'w', encoding='utf-8') as fh:
            json.dump(song, fh, ensure_ascii=False, indent=2)
            fh.write('\n')
        print(os.path.relpath(out, ROOT))


if __name__ == '__main__':
    main()
