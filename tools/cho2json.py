#!/usr/bin/env python3
"""Convert songs/src/*.cho (ChordPro-like authoring text) to songs/*.json (schema ethno-song/1).

Line syntax:   [Am]lyric with [C]chords || English translation || ×2
  [X]  chord from the song's chord_source (confirmed)
  [~X] chord inferred by analogy (not confirmed)
  [^X] chord taken from the audio analysis on a board-sourced song (not confirmed)
A chord at the very end of a line ("ja. [Am]") gets at_char == len(text): it sounds after the last word.
Directives: {key: value}; repeated keys (arr, note, evidence, uncertain, image, play) become lists.
Usage: python3 tools/cho2json.py [songs/src/01-x.cho ...]   (default: all)
"""
import glob, json, os, re, sys, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LISTS = {'arr': 'arrangement', 'note': 'notes', 'evidence': 'evidence', 'uncertain': 'uncertain', 'image': 'images', 'play': 'play'}
SCALARS = ['number', 'slug', 'title', 'subtitle', 'language', 'key', 'tempo', 'rhythm', 'scale', 'confidence', 'chord_source', 'audio']
CHORD = re.compile(r'\[([~^]?)([^\]]+)\]')


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
    song['sources'] = {'lyrics': 'Pjesme tekstovi.pdf (21.11.2026)', 'images': song.pop('images'), 'audio': song.pop('audio', None)}
    order = ['schema', 'number', 'slug', 'title', 'subtitle', 'language', 'key', 'tempo', 'rhythm', 'scale', 'confidence',
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
