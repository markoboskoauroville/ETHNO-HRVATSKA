#!/usr/bin/env python3
"""Render songs/*.json (schema ethno-song/1) to one simple A4 PDF per song:
page 1 = SINGERS (lyrics + translation side by side), page 2 = GUITAR (chords above the words + translation).
Every number used here is documented in songs/SCHEMA.md so a Swift app can reproduce the same pages.

Usage: python3 tools/render_pdf.py [songs/01-x.json ...] [--out PDFs] [--png DIR]
"""
import argparse, glob, json, os
import fitz  # PyMuPDF
import notation

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = {k: os.path.join(ROOT, 'fonts', f'OpenSans-{v}.ttf') for k, v in
         (('R', 'Regular'), ('I', 'Italic'), ('S', 'Semibold'), ('B', 'Bold'))}
METRIC = {k: fitz.Font(fontfile=v) for k, v in FONTS.items()}
notation.set_fonts(METRIC)

# ---- page geometry (points, 1 pt = 1/72 inch) ----
PAGE_W, PAGE_H = 595.28, 841.89          # A4 portrait
M_LEFT, M_RIGHT, M_TOP, M_BOTTOM = 54, 54, 54, 48
CONTENT_W = PAGE_W - M_LEFT - M_RIGHT     # 487.28
GUTTER = 22                               # between two columns
FOOTER_Y = PAGE_H - 28                    # footer baseline

# ---- colours (RGB 0..1) ----
def hexrgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
INK = hexrgb('#111111'); SUB = hexrgb('#666666'); TRANS = hexrgb('#6A6A6A'); LABEL = hexrgb('#A0A0A0')
RULE = hexrgb('#D0D0D0'); CHORD = hexrgb('#B03A2E'); CHORD_UNCONFIRMED = hexrgb('#B03A2E')   # send version: no grey chords; working notes live in songs/UNCERTAIN.md

# ---- type sizes at scale 1.0 ----
TITLE = 22; SUBTITLE = 10; INFO = 9.5; TAG = 9
S_LYRIC = 12.5; S_TRANS = 10.5; S_LABEL = 8; S_REPEAT = 10            # singers page
G_CHORD = 10.5; G_LYRIC = 12; G_TRANS = 8.8; G_LABEL = 8; G_PLAY = 9.5  # guitar page
FORM = 8.5; FOOTER = 7.5
CHORD_GAP = 5       # minimum space between two chord names on one row
MIN_SHRINK = 0.62     # a single line may shrink to this fraction of its size to fit its column
SCALE_STEPS = [1.0 - 0.02 * i for i in range(16)]   # 1.00 .. 0.70
BLOCK_GAP = 14      # space under the melody block (page 1) and under the rhythm box (page 2)


NOTE_CHARS = '\u2669\u266A'   # ♩ ♪ are not in Open Sans: drawn from Apple Symbols at 1.25 x the size
SYM_SCALE = 1.25


def segments(text):
    out, cur, sym = [], '', None
    for ch in text:
        is_sym = ch in NOTE_CHARS
        if sym is None or is_sym == sym:
            cur += ch
        else:
            out.append((cur, sym)); cur = ch
        sym = is_sym
    if cur:
        out.append((cur, sym))
    return out


def width(text, font, size):
    return sum(notation.SYM.text_length(t, fontsize=size * SYM_SCALE) if sym else METRIC[font].text_length(t, fontsize=size)
               for t, sym in segments(text))


def fit_size(text, font, size, maxw):
    w = width(text, font, size)
    if w <= maxw:
        return size
    return max(size * MIN_SHRINK, size * maxw / w)


class Page:
    def __init__(self, doc):
        self.p = doc.new_page(width=PAGE_W, height=PAGE_H)
        for k, f in FONTS.items():
            self.p.insert_font(fontname='OS' + k, fontfile=f)
        self.p.insert_font(fontname='ASYM', fontfile=notation.APPLE_SYMBOLS)

    def text(self, x, y, s, font, size, color):
        for t, sym in segments(s or ''):
            if sym:
                self.p.insert_text((x, y), t, fontname='ASYM', fontsize=size * SYM_SCALE, color=color)
                x += notation.SYM.text_length(t, fontsize=size * SYM_SCALE)
            else:
                self.p.insert_text((x, y), t, fontname='OS' + font, fontsize=size, color=color)
                x += METRIC[font].text_length(t, fontsize=size)

    def rtext(self, xr, y, s, font, size, color):
        self.text(xr - width(s, font, size), y, s, font, size, color)

    def rule(self, y):
        self.p.draw_line((M_LEFT, y), (PAGE_W - M_RIGHT, y), color=RULE, width=0.6)


def rhythm_text(song):
    r = song.get('rhythm')
    if isinstance(r, dict):
        t = f"{r['name']} {r['meter']}" if r.get('meter') and r['meter'] not in r['name'] else r['name']
        if r.get('grouping'):
            t += f" ({r['grouping']})"
        return t
    return r or ''


def info_line(song):
    parts = [f"Key {song['key']}"] if song.get('key') else []
    if song.get('tempo'): parts.append(f"Tempo {song['tempo']}")
    if rhythm_text(song): parts.append(f"Rhythm {rhythm_text(song)}")
    return '   ·   '.join(parts)


def header(page, song, tag):
    """Title block; returns the y where content starts."""
    y = M_TOP + TITLE * 0.9
    title = f"{song['number']}  {song['title']}"
    tsize = fit_size(title, 'B', TITLE, CONTENT_W)
    page.text(M_LEFT, y, title, 'B', tsize, INK)
    # no page tag (Marko 21.11.2026: no "FOR SINGERS" / "FOR GUITAR")
    y += 16
    page.text(M_LEFT, y, song.get('subtitle', ''), 'R', fit_size(song.get('subtitle', ''), 'R', SUBTITLE, CONTENT_W), SUB)
    info = info_line(song)
    if info:
        y += 14
        page.text(M_LEFT, y, info, 'R', fit_size(info, 'R', INFO, CONTENT_W), SUB)
    y += 10
    page.rule(y)
    return y + 18


def footer(page, song, which, n, total):
    """No footer is drawn (Marko 21.11.2026: "no footers at all"). FOOTER_Y stays only as the bottom limit of the layout."""
    return


# ------------------------------------------------------------------ singers page
def singers_blocks(song, k):
    """List of (height, draw(page, x, y)) per section at scale k. Two text columns: lyric | translation."""
    colw = (CONTENT_W - GUTTER) / 2
    blocks = []
    for si, sec in enumerate(song['sections']):
        items, h = [], 0.0
        if sec.get('name'):
            items.append(('label', h, sec['name'])); h += S_LABEL * k * 1.9
        for ln in sec['lines']:
            items.append(('line', h, ln)); h += S_LYRIC * k * 1.42
        h += 9 * k
        def draw(page, x, y, items=items):
            for kind, dy, obj in items:
                if kind == 'label':
                    page.text(x, y + dy + S_LABEL * k, obj.upper(), 'S', S_LABEL * k, LABEL)
                    continue
                base = y + dy + S_LYRIC * k
                rep = obj.get('repeat') or ''
                repw = width(rep, 'S', S_REPEAT * k) + 6 if rep else 0
                ls = fit_size(obj['text'], 'R', S_LYRIC * k, colw - repw)
                page.text(x, base, obj['text'], 'R', ls, INK)
                if rep:
                    page.text(x + width(obj['text'], 'R', ls) + 6, base, rep, 'S', S_REPEAT * k, LABEL)
                ts = fit_size(obj['translation'], 'I', S_TRANS * k, colw)
                page.text(x + colw + GUTTER, base, obj['translation'], 'I', ts, TRANS)
        blocks.append((h, draw))
    return blocks


def singers_blocks_stacked(song, k, colw):
    """Two-column fallback for long songs: per line the lyric, the translation under it (one block per line)."""
    blocks = []
    for sec in song['sections']:
        n = len(sec['lines'])
        for li, ln in enumerate(sec['lines']):
            h = 0.0
            label = sec.get('name') if li == 0 else None
            if label:
                h += S_LABEL * k * 1.9
            top = h
            h += S_LYRIC * k * 1.18 + S_TRANS * k * 0.95 * 1.25 + 2.5 * k
            if li == n - 1:
                h += 7 * k
            def draw(page, x, y, ln=ln, label=label, top=top):
                if label:
                    page.text(x, y + S_LABEL * k, label.upper(), 'S', S_LABEL * k, LABEL)
                base = y + top + S_LYRIC * k
                rep = ln.get('repeat') or ''
                repw = width(rep, 'S', S_REPEAT * k) + 6 if rep else 0
                ls = fit_size(ln['text'], 'R', S_LYRIC * k, colw - repw)
                page.text(x, base, ln['text'], 'R', ls, INK)
                if rep:
                    page.text(x + width(ln['text'], 'R', ls) + 6, base, rep, 'S', S_REPEAT * k, LABEL)
                ts = S_TRANS * k * 0.95
                page.text(x, base + ts * 1.25, ln['translation'], 'I', fit_size(ln['translation'], 'I', ts, colw), TRANS)
            blocks.append((h, draw))
    return blocks


def melody_block(song):
    mel = song.get('melody')
    if not mel or mel.get('status') == 'not_transcribed':   # no empty staff on a sheet that goes to the band
        return 0, lambda page, x, y: None
    mel = dict(mel); mel['label'] = ''   # send version: no draft note
    h, draw = notation.layout_melody(mel, CONTENT_W, 1.0)
    return h + BLOCK_GAP, lambda page, x, y: draw(page.p, x, y)


def rhythm_box(song):
    r = song.get('rhythm')
    if not isinstance(r, dict):
        return 0, lambda page, x, y: None
    r = dict(r)
    r['instrument_short'] = 'FRAME DRUM'
    if r.get('practice'):
        r['practice_text'] = 'MPA practice: ' + ' '.join('–' if c == '-' else c for c in r['practice'].split()) + ' (PA in place of TAK)'
    conf = r.get('confidence', '')
    r['confidence_text'] = ''   # send version: confidence stays in UNCERTAIN.md
    h, draw = notation.layout_rhythm(r, CONTENT_W, 1.0)
    legend = ('Frame drum staff: low line DUM (centre of the skin), high line TAK and KA (edge), x = PA, small note in ( ) = touch '
              '(ghost note). Cells as in MPA Academy: thick left line = accent, numbers under the cells restart on every accent.')
    lsize = 6.8
    lines = notation.wrap_text(legend, 'R', lsize, CONTENT_W)
    lh = lsize * 1.35
    def draw_all(page, x, y):
        draw(page.p, x, y)
        yy = y + h
        for i, l in enumerate(lines):
            page.text(x, yy + i * lh + lsize, l, 'R', lsize, LABEL)
        page.rule(yy + len(lines) * lh + 6)
    return h + len(lines) * lh + 6 + BLOCK_GAP, draw_all


# ------------------------------------------------------------------ guitar page
def chord_positions(text, chords, x, font, size, csize):
    out, prev_end = [], -1e9
    for c in sorted(chords, key=lambda c: c['at_char']):
        cx = x + width(text[:c['at_char']], font, size)
        if c['at_char'] >= len(text):
            cx += size * 0.35
        cx = max(cx, prev_end + CHORD_GAP)
        cw = width(c['chord'], 'B', csize)
        out.append((cx, c)); prev_end = cx + cw
    return out


def guitar_blocks(song, k, colw):
    """One block per lyric line (a section label rides on the section's first line) so long songs
    can flow from column 1 into column 2. A line whose text already appeared earlier shows no translation."""
    seen = set()
    blocks = []
    for sec in song['sections']:
        n = len(sec['lines'])
        for li, ln in enumerate(sec['lines']):
            h = 0.0
            label = sec.get('name') if li == 0 else None
            if label:
                h += G_LABEL * k * 1.9
            show_t = ln['text'] not in seen and bool(ln['translation'])
            seen.add(ln['text'])
            if ln['chords']:
                h += G_CHORD * k * 1.08
            top = h
            h += G_LYRIC * k * 1.14
            if show_t:
                h += G_TRANS * k * 1.25
            h += 2.5 * k
            if li == n - 1:
                h += 7 * k
            def draw(page, x, y, ln=ln, show_t=show_t, label=label, top=top):
                if label:
                    page.text(x, y + G_LABEL * k, label.upper(), 'S', G_LABEL * k, LABEL)
                base = y + top + G_LYRIC * k * 0.95
                rep = ln.get('repeat') or ''
                repw = width(rep, 'S', S_REPEAT * k) + 6 if rep else 0
                ls = fit_size(ln['text'], 'R', G_LYRIC * k, colw - repw - 30)
                csize = G_CHORD * k
                for cx, c in chord_positions(ln['text'], ln['chords'], x, 'R', ls, csize):
                    page.text(cx, base - G_LYRIC * k * 1.06, c['chord'], 'B', csize,
                              CHORD if c.get('confirmed', True) else CHORD_UNCONFIRMED)
                page.text(x, base, ln['text'], 'R', ls, INK)
                if rep:
                    page.text(x + width(ln['text'], 'R', ls) + 6, base, rep, 'S', S_REPEAT * k, LABEL)
                if show_t:
                    t = ln['translation']
                    page.text(x, base + G_TRANS * k * 1.25, t, 'I', fit_size(t, 'I', G_TRANS * k, colw), TRANS)
            blocks.append((h, draw))
    return blocks


def play_block(song, k):
    rows = song.get('play') or []
    if not rows:
        return 0, lambda page, x, y: None
    lh = G_PLAY * k * 1.55
    def draw(page, x, y):
        for i, r in enumerate(rows):
            b = y + i * lh + G_PLAY * k
            lab = r['label'] + ':'
            page.text(x, b, lab, 'S', G_PLAY * k, SUB)
            cx = x + width(lab, 'S', G_PLAY * k) + 6
            page.text(cx, b, r['chords'], 'B', fit_size(r['chords'], 'B', G_PLAY * k, CONTENT_W - (cx - x)), CHORD)
    return len(rows) * lh + 8 * k, draw


def wrap(text, font, size, maxw):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if width(t, font, size) <= maxw or not cur:
            cur = t
        else:
            lines.append(cur); cur = w
    if cur: lines.append(cur)
    return lines


def form_block(song, k):
    """Arrangement ('Form', two columns of bullets) + legend lines, small, at the bottom of the guitar page."""
    size = FORM * k; lh = size * 1.38
    colw = (CONTENT_W - GUTTER) / 2
    bullets = []
    for a in song.get('arrangement') or []:
        for i, w in enumerate(wrap(a, 'R', size, colw - 10)):
            bullets.append(('•  ' if i == 0 else '    ') + w)
    half = (len(bullets) + 1) // 2
    while 0 < half < len(bullets) and bullets[half].startswith('    '):
        half += 1                      # never split one bullet across the two columns
    legend = []
    leg = [w for n in legend for w in wrap(n, 'I', size, CONTENT_W)]
    rows = max(half, len(bullets) - half)
    h = (1 + rows) * lh * (1 if bullets else 0) + len(leg) * lh + 8 * k
    def draw(page, x, y):
        page.rule(y - 2)
        yy = y + 6 * k + size
        if bullets:
            page.text(x, yy, 'FORM', 'S', size, LABEL)
            yy += lh
            for i, b in enumerate(bullets):
                col, row = (0, i) if i < half else (1, i - half)
                page.text(x + col * (colw + GUTTER), yy + row * lh, b, 'R', size, SUB)
            yy += rows * lh
        for i, w in enumerate(leg):
            page.text(x, yy + i * lh, w, 'I', size, SUB)
    return h, draw


# ------------------------------------------------------------------ packing
def pack(blocks, avail, ncols):
    """Blocks in order into ncols columns of height avail; returns columns or None.
    The columns are balanced: the smallest column height (from total / ncols upwards, 2 pt steps) that still fits."""
    hs = [b[0] for b in blocks]
    total = sum(hs)
    if not blocks or max(hs) > avail:
        return None if blocks else [[]]
    target = max(total / ncols, max(hs))
    while target <= avail + 1e-6:
        cols, cur, h = [], [], 0.0
        for b in blocks:
            if h + b[0] > target + 1e-6 and cur:
                cols.append(cur); cur, h = [], 0.0
            cur.append(b); h += b[0]
        cols.append(cur)
        if len(cols) <= ncols:
            return cols
        target += 2
    return None


def draw_cols(page, cols, y0, colw):
    for ci, col in enumerate(cols):
        x, y = M_LEFT + ci * (colw + GUTTER), y0
        for h, draw in col:
            draw(page, x, y); y += h


def render(song, out_pdf):
    doc = fitz.open()
    # page 1: singers
    p1 = Page(doc)
    y0 = header(p1, song, 'FOR SINGERS')
    mh, mdraw = melody_block(song)
    avail = FOOTER_Y - 18 - y0 - mh
    s_cols = None
    half = (CONTENT_W - GUTTER) / 2
    for ncols, k in [(1, k) for k in SCALE_STEPS[:11]] + [(2, k) for k in SCALE_STEPS]:   # 1 col >= 0.80, else 2 cols
        blocks = singers_blocks(song, k) if ncols == 1 else singers_blocks_stacked(song, k, half)
        cols = pack(blocks, avail, ncols)
        if cols:
            s_cols = (ncols, k, cols); break
    if not s_cols:
        raise SystemExit(f"{song['title']}: singers page does not fit even at scale {SCALE_STEPS[-1]:.2f}")
    mdraw(p1, M_LEFT, y0)
    draw_cols(p1, s_cols[2], y0 + mh, CONTENT_W if s_cols[0] == 1 else half)
    footer(p1, song, 'singers', 1, 2)   # draw before the next page: PyMuPDF orphans earlier Page objects
    # page 2: guitar
    p2 = Page(doc)
    y0 = header(p2, song, 'FOR GUITAR')
    rh, rdraw = rhythm_box(song)
    rdraw(p2, M_LEFT, y0)
    y0 += rh
    chosen = None
    candidates = ([(1, k) for k in SCALE_STEPS[:5]] + [(2, k) for k in SCALE_STEPS[:13]] +
                  [(3, k) for k in SCALE_STEPS])   # 1 col >= 0.92, 2 cols >= 0.76, else 3 cols >= 0.70
    for ncols, k in candidates:
        colw = (CONTENT_W - GUTTER * (ncols - 1)) / ncols
        ph, pdraw = play_block(song, k)
        fh, fdraw = form_block(song, min(1.0, k + 0.05))
        avail = FOOTER_Y - 16 - y0 - ph - fh - 10
        cols = pack(guitar_blocks(song, k, colw), avail, ncols)
        if cols:
            chosen = (ncols, colw, k, ph, pdraw, fh, fdraw, cols); break
    if not chosen:
        raise SystemExit(f"{song['title']}: guitar page does not fit")
    ncols, colw, k, ph, pdraw, fh, fdraw, cols = chosen
    pdraw(p2, M_LEFT, y0)
    draw_cols(p2, cols, y0 + ph, colw)
    fdraw(p2, M_LEFT, FOOTER_Y - 16 - fh)
    footer(p2, song, 'guitar', 2, 2)
    doc.set_metadata({'title': f"{song['number']} {song['title']}", 'author': 'Etno orkestar · ETHNO-HRVATSKA',
                      'subject': 'Melody, lyrics, translation, chords and frame-drum rhythm', 'creator': 'ETHNO-HRVATSKA tools/render_pdf.py'})
    doc.subset_fonts()        # Apple Symbols is 1 MB: embed only the glyphs used
    doc.save(out_pdf, garbage=3, deflate=True)
    return {'pdf': out_pdf, 'guitar_columns': ncols, 'guitar_scale': round(k, 2),
            'singers_columns': s_cols[0], 'singers_scale': round(s_cols[1], 2)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('songs', nargs='*')
    ap.add_argument('--out', default=os.path.join(ROOT, 'PDFs'))
    ap.add_argument('--png', default=None, help='also write page PNGs (110 dpi) here for checking')
    a = ap.parse_args()
    files = a.songs or sorted(glob.glob(os.path.join(ROOT, 'songs', '[0-9]*.json')))
    os.makedirs(a.out, exist_ok=True)
    for f in files:
        song = json.load(open(f, encoding='utf-8'))
        out = os.path.join(a.out, f"{song['number']} {song['title']}.pdf")
        r = render(song, out)
        print(f"{os.path.basename(out)}: singers {r['singers_columns']} col, scale {r['singers_scale']}; "
              f"guitar {r['guitar_columns']} col, scale {r['guitar_scale']}")
        if a.png:
            os.makedirs(a.png, exist_ok=True)
            for i, pg in enumerate(fitz.open(out)):
                pg.get_pixmap(dpi=110).save(os.path.join(a.png, f"{song['number']}-p{i + 1}.png"))


if __name__ == '__main__':
    main()
