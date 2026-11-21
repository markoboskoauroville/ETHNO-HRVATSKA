"""Vector music notation for the song sheets (21.11.2026): the MELODY block (a five-line staff with the vocal line,
chord names above, syllables below) and the RHYTHM box (frame-drum notation as MPA Academy writes it: the cell grid
D T K P - with accents and spoons, plus a two-line frame-drum staff: low line = Dum, high line = Tak / Ka / Pa).

Everything is drawn with PyMuPDF lines, ovals and curves; the only glyphs are the G clef and the accidentals from the
macOS system font Apple Symbols, digits and words in Open Sans. Every number is in songs/SCHEMA.md section 5 and 6.
"""
import math
import fitz

APPLE_SYMBOLS = '/System/Library/Fonts/Apple Symbols.ttf'
SYM = fitz.Font(fontfile=APPLE_SYMBOLS)
G_CLEF, FLAT, SHARP, NATURAL = '\U0001D11E', '♭', '♯', '♮'

INK = (0.067, 0.067, 0.067)
GREY = (0.40, 0.40, 0.40)
LIGHT = (0.63, 0.63, 0.63)
CHORD = (0.69, 0.227, 0.18)
WHITE = (1, 1, 1)

# ------------------------------------------------------------------ pitch helpers
LETTERS = 'CDEFGAB'
SHARP_ORDER = 'FCGDAEB'
FLAT_ORDER = 'BEADGCF'
# staff positions (0 = bottom line E4 in the treble clef, one step = half a space)
SHARP_POS = {'F': 8, 'C': 5, 'G': 9, 'D': 6, 'A': 3, 'E': 7, 'B': 4}
FLAT_POS = {'B': 4, 'E': 7, 'A': 3, 'D': 6, 'G': 2, 'C': 5, 'F': 1}


def parse_pitch(p):
    """'E4', 'F#4', 'Bb3', 'Ed4' (E half-flat), 'Bn4' (natural) -> (letter, acc, octave). acc in '', '#', 'b', 'd', 'n'."""
    letter, rest = p[0].upper(), p[1:]
    acc = ''
    if rest and rest[0] in '#bdn':
        acc, rest = rest[0], rest[1:]
    return letter, acc, int(rest)


def key_accidentals(ks):
    """{letter: acc} implied by a key signature {'fifths': n, 'half_flats': ['E']}."""
    out = {}
    n = ks.get('fifths', 0)
    for L in (SHARP_ORDER[:n] if n > 0 else FLAT_ORDER[:-n]):
        out[L] = '#' if n > 0 else 'b'
    for L in ks.get('half_flats', []) or []:
        out[L] = 'd'
    return out


def staff_pos(letter, octave, clef):
    """Diatonic staff position: 0 = bottom line. Treble: E4 = 0. 'treble8' (tenor voice) is written an octave up."""
    if clef == 'treble8':
        octave += 1
    return octave * 7 + LETTERS.index(letter) - (4 * 7 + 2)


# ------------------------------------------------------------------ small drawing helpers
def line(pg, a, b, w=0.6, color=INK):
    pg.draw_line(a, b, color=color, width=w)


def head(pg, cx, cy, sp, filled=True, scale=1.0):
    """Notehead: ellipse 1.30 sp x 0.92 sp, turned -20 degrees; hollow heads have a 0.16 sp outline."""
    w, h = 1.30 * sp * scale / 2, 0.92 * sp * scale / 2
    r = fitz.Rect(cx - w, cy - h, cx + w, cy + h)
    sh = pg.new_shape()
    sh.draw_oval(r)
    m = (fitz.Point(cx, cy), fitz.Matrix(-20))
    if filled:
        sh.finish(color=INK, fill=INK, width=0.1, morph=m)
    else:
        sh.finish(color=INK, fill=WHITE, width=0.16 * sp * 1.3, morph=m)
    sh.commit()


def xhead(pg, cx, cy, sp):
    d = 0.5 * sp
    line(pg, (cx - d, cy - d), (cx + d, cy + d), 0.9)
    line(pg, (cx - d, cy + d), (cx + d, cy - d), 0.9)


def glyph(pg, x, y, ch, size, color=INK):
    pg.insert_text((x, y), ch, fontname='ASYM', fontsize=size, color=color)


def ensure_fonts(pg):
    pg.insert_font(fontname='ASYM', fontfile=APPLE_SYMBOLS)


def half_flat(pg, x, y_pos_line, sp):
    """Half-flat (Arabic notation): a flat with a slash through its stem. x = left edge, y_pos_line = staff y of the note."""
    size = 3.4 * sp
    glyph(pg, x, y_pos_line + 0.45 * sp, FLAT, size)
    line(pg, (x - 0.15 * sp, y_pos_line - 1.05 * sp), (x + 1.05 * sp, y_pos_line - 1.75 * sp), 0.7)


def accidental(pg, x, y, acc, sp):
    """Accidental left edge at x for a note at staff y. Width 1.15 sp (+0.45 gap)."""
    if acc == 'd':
        half_flat(pg, x, y, sp)
        return
    ch = {'b': FLAT, '#': SHARP, 'n': NATURAL}[acc]
    size = 3.4 * sp
    dy = {'b': 0.45, '#': 1.05, 'n': 1.05}[acc] * sp
    glyph(pg, x, y + dy, ch, size)


def rest(pg, cx, top, sp, length):
    """Rests centred at cx on a five-line staff whose top line is at y=top (also used on the drum staff)."""
    mid = top + 2 * sp
    if length >= 8:                                   # half rest: block sitting on the middle line
        pg.draw_rect(fitz.Rect(cx - 0.6 * sp, mid - 0.5 * sp, cx + 0.6 * sp, mid), color=INK, fill=INK, width=0)
    elif length >= 4:                                 # quarter rest: zigzag
        pts = [(cx + 0.2 * sp, mid - 1.5 * sp), (cx + 0.6 * sp, mid - 0.9 * sp), (cx - 0.1 * sp, mid - 0.1 * sp),
               (cx + 0.5 * sp, mid + 0.6 * sp), (cx - 0.3 * sp, mid + 0.4 * sp), (cx + 0.2 * sp, mid + 1.3 * sp)]
        pg.draw_polyline(pts, color=INK, width=0.9 * sp / 5.6 * 1.4)
    else:                                             # eighth (one dot) / sixteenth (two dots) rest
        n = 1 if length >= 2 else 2
        x0, y0 = cx + 0.45 * sp, mid - 0.8 * sp
        line(pg, (x0, y0), (x0 - 0.75 * sp, y0 + (1.5 + n) * sp * 0.75), 0.75)
        for i in range(n):
            yy = y0 + i * sp * 0.75
            pg.draw_circle((x0 - 0.75 * sp - 0.05 * sp + i * -0.25 * sp, yy + 0.05 * sp), 0.32 * sp, color=INK, fill=INK, width=0)
            line(pg, (x0 - 0.75 * sp + i * -0.25 * sp, yy + 0.2 * sp), (x0 - i * 0.25 * sp, yy), 0.7)


def flag(pg, sx, sy, sp, up, n):
    """n flags (1 = eighth, 2 = sixteenth) on a stem tip (sx, sy)."""
    s = 1 if up else -1
    for i in range(n):
        y = sy + s * i * 0.8 * sp
        pg.draw_bezier((sx, y), (sx + 0.2 * sp, y + s * 1.0 * sp), (sx + 1.3 * sp, y + s * 1.3 * sp),
                       (sx + 0.9 * sp, y + s * 2.5 * sp), color=INK, width=0.9)


def tie(pg, x1, x2, y, sp, below):
    s = 1 if below else -1
    pg.draw_bezier((x1, y), (x1 + (x2 - x1) * 0.25, y + s * 0.9 * sp), (x1 + (x2 - x1) * 0.75, y + s * 0.9 * sp), (x2, y),
                   color=INK, width=0.8)


# ------------------------------------------------------------------ the melody staff
SP_MELODY = 5.6          # staff space at scale 1 (staff height 22.4 pt)


def bar_len(time):
    """Length of one bar in sixteenths: '2/4' -> 8, '3/4' -> 12, '5/8' -> 10."""
    n, d = (int(v) for v in time.split('/'))
    return n * 16 // d


def beat_groups(time, grouping=None):
    """Beam groups in sixteenths inside one bar: x/4 -> quarters (4); x/8 -> the grouping ('2+3' -> [4, 6])."""
    n, d = (int(v) for v in time.split('/'))
    if d == 8:
        parts = [int(g) for g in grouping.split('+')] if grouping else [2] * (n // 2) + ([n % 2] if n % 2 else [])
        return [p * 2 for p in parts]
    return [16 // d] * n


def layout_melody(mel, width, k=1.0):
    """Measure the melody block at scale k. Returns (height, draw(page, x, y))."""
    sp = SP_MELODY * k
    systems = mel.get('systems') or []
    status = mel.get('status', 'draft')
    label_h = 8 * k * 1.9
    sys_h = []
    geo = []
    for si, notes in enumerate(systems if systems else [[]]):
        g = system_geometry(mel, notes, width, sp, first=(si == 0), last=(si == len(systems) - 1) or not systems)
        geo.append(g)
        sys_h.append(g['height'])
    h = label_h + sum(sys_h) + 6 * k

    def draw(pg, x, y):
        ensure_fonts(pg)
        lab = f"MELODY  ·  {mel.get('label', '')}"
        ls = 8 * k
        if text_w(lab, 'S', ls) > width:
            ls = max(ls * 0.62, ls * width / text_w(lab, 'S', ls))
        pg.insert_text((x, y + 8 * k), lab, fontname='OSS', fontsize=ls, color=LIGHT)
        yy = y + label_h
        for g in geo:
            g['draw'](pg, x, yy)
            yy += g['height']
    return h, draw


def system_geometry(mel, notes, width, sp, first, last):
    clef = mel.get('clef', 'treble')
    ks = mel.get('key_signature') or {}
    kacc = key_accidentals(ks)
    time = mel.get('time', '4/4')
    blen = bar_len(time)
    groups = beat_groups(time, mel.get('grouping'))
    fifths = ks.get('fifths', 0)
    hf = ks.get('half_flats', []) or []
    # prefix: clef 3.9 sp, key signature 1.3 sp per sign + 0.8 sp, time 2.6 sp (first system only) + 1.0 sp
    nsig = abs(fifths) + len(hf)
    prefix = 0.6 * sp + 3.9 * sp + (nsig * 1.3 * sp + 0.8 * sp if nsig else 0.4 * sp) + ((2.6 + 1.0) * sp if first else 0)
    lyr_size = 9.5 * sp / SP_MELODY
    chord_size = 9.5 * sp / SP_MELODY

    # elements: notes with natural widths, barlines after every full bar
    elems, acc16 = [], mel.get('_start16', 0)
    for n in notes:
        letter, acc, octv = ('B', '', 4) if n['pitch'] == 'R' else parse_pitch(n['pitch'])
        shown = None
        if n['pitch'] != 'R':
            want = acc or ''
            have = kacc.get(letter, '')
            if want == 'n':
                want = ''
            if want != have:
                shown = want if want else 'n'
        syl = n.get('syllable') or ''
        sw = text_w(syl, 'R', lyr_size) if syl else 0
        cw = text_w(n.get('chord') or '', 'B', chord_size) if n.get('chord') else 0
        base = (2.2 + 1.5 * math.sqrt(n['len'] / 2)) * sp
        w = max(base, sw + 0.9 * sp, cw + 0.8 * sp) + (1.6 * sp if shown else 0)
        elems.append({'kind': 'note', 'n': n, 'w': w, 'acc': shown, 'start16': acc16})
        acc16 += n['len']
        if acc16 % blen == 0:
            elems.append({'kind': 'bar', 'w': 1.4 * sp})
    if elems and elems[-1]['kind'] == 'bar' and last:
        elems[-1]['final'] = True
    natural = sum(e['w'] for e in elems)
    avail = width - prefix
    stretch = avail / natural if natural else 1.0
    if not notes:
        stretch = 1.0
    # vertical extents
    poss = []
    for e in elems:
        if e['kind'] == 'note' and e['n']['pitch'] != 'R':
            L, a, o = parse_pitch(e['n']['pitch'])
            e['pos'] = staff_pos(L, o, clef)
            poss.append(e['pos'])
    hi_pos = max(poss + [8])
    lo_pos = min(poss + [0])
    # stems are 3.5 sp: up-stems from low notes reach pos+7, down-stems from high notes reach pos-7
    top_reach = max(hi_pos, max([p + 7 for p in poss if p < 4] + [8]))
    bot_reach = min(lo_pos, min([p - 7 for p in poss if p >= 4] + [0]))
    above = (top_reach - 8) * sp / 2 + 1.0 * sp         # space above the top line needed by notes
    below = (0 - bot_reach) * sp / 2 + 0.8 * sp
    chord_gap = max(above, 1.2 * sp) + chord_size * 0.2
    staff_top_off = chord_size + chord_gap                # from system top to the staff's top line
    lyr_base_off = staff_top_off + 4 * sp + max(below, 1.0 * sp) + lyr_size
    height = lyr_base_off + lyr_size * 0.9 + 4 * sp / SP_MELODY

    def draw(pg, x, y):
        top = y + staff_top_off
        bot = top + 4 * sp
        for i in range(5):
            line(pg, (x, top + i * sp), (x + width, top + i * sp), 0.5)
        line(pg, (x, top), (x, bot), 0.6)
        # clef
        cx = x + 0.6 * sp
        glyph(pg, cx, bot + 1.15 * sp if clef != 'treble8' else bot + 1.15 * sp, G_CLEF, 7.4 * sp)
        if clef == 'treble8':
            pg.insert_text((cx + 1.15 * sp, bot + 2.9 * sp), '8', fontname='OSR', fontsize=1.7 * sp, color=INK)
        kx = cx + 3.9 * sp
        # key signature
        signs = [(L, '#' if fifths > 0 else 'b') for L in (SHARP_ORDER[:fifths] if fifths > 0 else FLAT_ORDER[:-fifths])]
        signs += [(L, 'd') for L in hf]
        for L, a in signs:
            p = (SHARP_POS if a == '#' else FLAT_POS)[L]
            accidental(pg, kx, bot - p * sp / 2, a, sp)
            kx += 1.3 * sp
        kx += 0.8 * sp if signs else 0.4 * sp
        if first:
            num, den = time.split('/')
            ts = 2.75 * sp
            for txt, base in ((num, top + 2 * sp), (den, top + 4 * sp)):
                tw = text_w(txt, 'B', ts)
                pg.insert_text((kx + 1.3 * sp - tw / 2, base - 0.02 * sp), txt, fontname='OSB', fontsize=ts, color=INK)
            kx += (2.6 + 1.0) * sp
        # chord + lyric rows
        chord_base = y + chord_size
        lyr_base = y + lyr_base_off
        xx = kx
        placed = []
        for e in elems:
            w = e['w'] * stretch
            if e['kind'] == 'bar':
                bx = xx + w / 2
                if e.get('final'):
                    line(pg, (bx - 1.2, top), (bx - 1.2, bot), 0.6)
                    line(pg, (x + width - 1.0, top), (x + width - 1.0, bot), 2.0)
                else:
                    line(pg, (bx, top), (bx, bot), 0.6)
                xx += w
                continue
            n = e['n']
            hx = xx + (1.6 * sp if e['acc'] else 0) + 0.95 * sp       # head centre
            e['hx'] = hx
            placed.append(e)
            if n.get('chord'):
                pg.insert_text((hx - 0.65 * sp, chord_base), n['chord'], fontname='OSB', fontsize=chord_size, color=CHORD)
            xx += w
        if notes and elems and elems[-1]['kind'] != 'bar':
            line(pg, (x + width, top), (x + width, bot), 0.6)
        draw_notes(pg, placed, top, bot, sp, groups, blen)
        # syllables, hyphens
        prev = None
        for e in placed:
            syl = e['n'].get('syllable') or ''
            if not syl:
                prev = None if not e['n'].get('tie') else prev
                continue
            txt = syl[:-1] if syl.endswith('-') else syl
            tw = text_w(txt, 'R', lyr_size)
            sx = e['hx'] - tw / 2
            pg.insert_text((sx, lyr_base), txt, fontname='OSR', fontsize=lyr_size, color=INK)
            if prev is not None:
                px_end = prev[0]
                gap_mid = (px_end + sx) / 2
                hw = text_w('-', 'R', lyr_size)
                if sx - px_end > hw + 1:
                    pg.insert_text((gap_mid - hw / 2, lyr_base), '-', fontname='OSR', fontsize=lyr_size, color=INK)
            prev = (sx + tw,) if syl.endswith('-') else None
        if not notes:
            # empty system: four empty bars to write the melody in by hand
            span = (x + width - kx) / 4
            for i in range(1, 4):
                line(pg, (kx + i * span, top), (kx + i * span, bot), 0.6)
            line(pg, (x + width, top), (x + width, bot), 0.6)
    return {'height': height, 'draw': draw}


def draw_notes(pg, placed, top, bot, sp, groups, blen):
    """Heads, stems, beams, flags, dots, ledger lines, ties for the placed notes of one system."""
    def ypos(p):
        return bot - p * sp / 2
    # beam groups: consecutive notes shorter than a quarter inside one beat group of the bar
    bounds = []
    acc = 0
    for g in groups:
        bounds.append((acc, acc + g)); acc += g
    def group_of(start16):
        s = start16 % blen
        for i, (a, b) in enumerate(bounds):
            if a <= s < b:
                return (start16 // blen, i)
        return (start16 // blen, -1)
    runs, cur = [], []
    for e in placed:
        n = e['n']
        beamable = n['pitch'] != 'R' and n['len'] < 4
        if cur and (not beamable or group_of(e['start16']) != group_of(cur[-1]['start16'])):
            runs.append(cur); cur = []
        if beamable:
            cur.append(e)
        else:
            runs.append([e])
    if cur:
        runs.append(cur)
    for run in runs:
        notes = [e for e in run if e['n']['pitch'] != 'R']
        if not notes:
            for e in run:
                rest(pg, e['hx'], top, sp, e['n']['len'])
            continue
        avgpos = sum(e['pos'] for e in notes) / len(notes)
        up = avgpos < 4
        for e in notes:
            p, hx = e['pos'], e['hx']
            hy = ypos(p)
            # ledger lines
            for lp in range(-2, p - 1, -2):
                line(pg, (hx - 1.05 * sp, ypos(lp)), (hx + 1.05 * sp, ypos(lp)), 0.6)
            for lp in range(10, p + 1, 2):
                line(pg, (hx - 1.05 * sp, ypos(lp)), (hx + 1.05 * sp, ypos(lp)), 0.6)
            ln = e['n']['len']
            head(pg, hx, hy, sp, filled=ln < 8)
            if e['acc']:
                accidental(pg, hx - 0.95 * sp - 1.55 * sp, hy, e['acc'], sp)
            if ln in (3, 6, 12):
                dy = -sp / 2 if p % 2 == 0 else 0
                pg.draw_circle((hx + 1.15 * sp, hy + dy), 0.2 * sp, color=INK, fill=INK, width=0)
            e['hy'] = hy
        if len(notes) == 1 or len(run) == 1:
            e = notes[0]
            ln = e['n']['len']
            if ln >= 16:
                continue
            up1 = e['pos'] < 4
            sx = e['hx'] + (0.6 * sp if up1 else -0.6 * sp)
            sy = e['hy'] + (-3.5 * sp if up1 else 3.5 * sp)
            line(pg, (sx, e['hy'] - (0.1 * sp if up1 else -0.1 * sp)), (sx, sy), 0.75)
            if ln < 4:
                flag(pg, sx, sy, sp, up1, 1 if ln >= 2 else 2)
            continue
        # beamed run, horizontal beam
        if up:
            by = min(e['hy'] for e in notes) - 3.5 * sp
        else:
            by = max(e['hy'] for e in notes) + 3.5 * sp
        xs = []
        for e in notes:
            sx = e['hx'] + (0.6 * sp if up else -0.6 * sp)
            line(pg, (sx, e['hy']), (sx, by), 0.75)
            xs.append(sx)
        bw = 0.5 * sp
        s = 1 if up else -1
        pg.draw_rect(fitz.Rect(xs[0], by - (0 if up else bw), xs[-1], by + (bw if up else 0)), color=INK, fill=INK, width=0)
        # secondary beams for sixteenths
        y2 = by + s * 0.8 * sp
        for i, e in enumerate(notes):
            if e['n']['len'] in (1,):
                nb = notes[i + 1] if i + 1 < len(notes) and notes[i + 1]['n']['len'] == 1 else None
                if nb:
                    pg.draw_rect(fitz.Rect(xs[i], y2 - (0 if up else bw), xs[i + 1], y2 + (bw if up else 0)), color=INK, fill=INK, width=0)
                elif not (i > 0 and notes[i - 1]['n']['len'] == 1):
                    x1 = xs[i] - 1.2 * sp if i == len(notes) - 1 else xs[i]
                    x2 = xs[i] if i == len(notes) - 1 else xs[i] + 1.2 * sp
                    pg.draw_rect(fitz.Rect(x1, y2 - (0 if up else bw), x2, y2 + (bw if up else 0)), color=INK, fill=INK, width=0)
    # ties
    for a, b in zip(placed, placed[1:]):
        if b['n'].get('tie') and 'hy' in a and 'hy' in b:
            below = a['pos'] < 4
            yy = a['hy'] + (0.9 * sp if below else -0.9 * sp)
            tie(pg, a['hx'] + 0.6 * sp, b['hx'] - 0.6 * sp, yy, sp, below)


# ------------------------------------------------------------------ text width (Open Sans, shared with render_pdf)
_FONTS = {}


def set_fonts(metric):
    _FONTS.update(metric)


NOTE_CHARS = '\u2669\u266A'      # ♩ ♪: not in Open Sans, drawn from Apple Symbols at 1.25 x


def _segs(s):
    out = []
    for ch in s:
        sym = ch in NOTE_CHARS
        if out and out[-1][1] == sym:
            out[-1][0] += ch
        else:
            out.append([ch, sym])
    return out


def text_w(s, font, size):
    return sum(SYM.text_length(t, fontsize=size * 1.25) if sym else _FONTS[font].text_length(t, fontsize=size)
               for t, sym in _segs(s or ''))


def mtext(pg, x, y, s, font, size, color):
    for t, sym in _segs(s or ''):
        if sym:
            pg.insert_text((x, y), t, fontname='ASYM', fontsize=size * 1.25, color=color)
            x += SYM.text_length(t, fontsize=size * 1.25)
        else:
            pg.insert_text((x, y), t, fontname='OS' + font, fontsize=size, color=color)
            x += _FONTS[font].text_length(t, fontsize=size)


# ------------------------------------------------------------------ the rhythm box (frame drum, MPA)
SYLL = {'D': 'DUM', 'T': 'TAK', 'K': 'KA', 'P': 'PA', '-': '–', '': ''}


def rhythm_cells(r):
    return ['' if c in ('.', '_') else c for c in r['cells']]


def layout_rhythm(r, width, k=1.0):
    """The RHYTHM box, full content width. Left: text column 168 pt. Right: cells grid, two-line drum staff,
    syllables. Returns (height, draw(page, x, y))."""
    cells = rhythm_cells(r)
    n = len(cells)
    text_w_col = 168 * k
    clef_w = 22 * k
    area = width - text_w_col - clef_w
    cw = min(30 * k, area / n)
    cell_h = 15 * k
    num_h = 7 * k
    spoon_h = 9 * k
    gap = 3 * k
    beam_h = 14 * k
    line_gap = 9 * k
    syl_h = 10 * k
    note_h = num_h + cell_h + spoon_h + gap + beam_h + line_gap + 4 * k + syl_h
    lines = rhythm_text_lines(r, text_w_col - 10 * k, k)
    text_h = sum(lh for _, _, _, lh in lines)
    h = max(note_h, text_h) + 4 * k

    def draw(pg, x, y):
        ensure_fonts(pg)
        # left column
        yy = y
        for s, font, size, lh in lines:
            yy += lh
            col = LIGHT if font == 'S' else (INK if font == 'B' else GREY)
            mtext(pg, x, yy - lh * 0.28, s, font, size, col)
        # cells grid (MPA Lab: boxes, accents = thick left line, numbers above, spoons below)
        gx = x + text_w_col + clef_w
        cy = y + num_h
        spoon = 0
        acc = [c not in ('-', '') for c in cells]
        for i, c in enumerate(cells):
            cx0 = gx + i * cw
            pg.draw_rect(fitz.Rect(cx0, cy, cx0 + cw, cy + cell_h), color=INK, width=0.6)
            if acc[i]:
                pg.draw_rect(fitz.Rect(cx0, cy, cx0 + 2.4 * k, cy + cell_h), color=INK, fill=INK, width=0)
            lab = '–' if c == '-' else c
            lw = text_w(lab, 'S', 10.5 * k)
            pg.insert_text((cx0 + cw / 2 - lw / 2 + (0.8 * k if acc[i] else 0), cy + cell_h * 0.72), lab, fontname='OSS',
                           fontsize=10.5 * k, color=INK if c != '-' else GREY)
            num = str(i + 1)
            nw = text_w(num, 'R', 6 * k)
            pg.insert_text((cx0 + cw / 2 - nw / 2, cy - 1.8 * k), num, fontname='OSR', fontsize=6 * k, color=LIGHT)
            spoon = 1 if acc[i] else spoon + 1
            sp_txt = str(spoon)
            fnt = 'B' if spoon == 1 else 'R'
            sw = text_w(sp_txt, fnt, 7 * k)
            pg.insert_text((cx0 + cw / 2 - sw / 2, cy + cell_h + 7.5 * k), sp_txt, fontname='OS' + fnt, fontsize=7 * k,
                           color=INK if spoon == 1 else LIGHT)
        # two-line frame-drum staff: high line = Tak / Ka / Pa (edge), low line = Dum (centre)
        hi_y = cy + cell_h + spoon_h + gap + beam_h
        lo_y = hi_y + line_gap
        sx0, sx1 = gx - clef_w + 2 * k, gx + n * cw
        line(pg, (sx0, hi_y), (sx1, hi_y), 0.6)
        line(pg, (sx0, lo_y), (sx1, lo_y), 0.6)
        # percussion clef: two thick bars
        for dx in (0, 3.2 * k):
            pg.draw_rect(fitz.Rect(sx0 + 1.5 * k + dx, hi_y - 2 * k, sx0 + 3.1 * k + dx, lo_y + 2 * k), color=INK, fill=INK, width=0)
        # time signature, small, between the clef and the first cell
        num, den = r['meter'].split('/')
        ts = 7.5 * k
        tx = sx0 + 11.5 * k
        for t, by in ((num, hi_y - 0.6 * k), (den, lo_y + ts * 0.72 + 0.4 * k)):
            tw = text_w(t, 'B', ts)
            pg.insert_text((tx - tw / 2, by), t, fontname='OSB', fontsize=ts, color=INK)
        # repeat end barline (the bar loops)
        line(pg, (sx1 - 3.2 * k, hi_y - 3 * k), (sx1 - 3.2 * k, lo_y + 3 * k), 0.6)
        pg.draw_rect(fitz.Rect(sx1 - 1.6 * k, hi_y - 3 * k, sx1, lo_y + 3 * k), color=INK, fill=INK, width=0)
        for yy2 in (hi_y + line_gap * 0.3, hi_y + line_gap * 0.7):
            pg.draw_circle((sx1 - 6 * k, yy2), 0.9 * k, color=INK, fill=INK, width=0)
        # notes
        value = int(r.get('cell', 16))
        groups = [int(g) for g in str(r.get('grouping', '')).replace(' ', '').split('+') if g.isdigit()]
        if sum(groups) != n:                       # no usable grouping: beam per quarter-note beat
            per = max(1, value // 4)
            groups = [per] * (n // per)
        beam_y = hi_y - 13 * k
        heads = []
        for i, c in enumerate(cells):
            hx = gx + i * cw + cw / 2
            if c == '':
                heads.append(None)
                continue
            if c == 'D':
                hy = lo_y
            else:
                hy = hi_y
            if c == '-':
                head(pg, hx, hy, 5.2 * k, filled=True, scale=0.62)
                for side in (-1, 1):
                    pg.draw_bezier((hx + side * 3.4 * k, hy - 3.0 * k), (hx + side * 4.6 * k, hy - 1.0 * k),
                                   (hx + side * 4.6 * k, hy + 1.0 * k), (hx + side * 3.4 * k, hy + 3.0 * k), color=GREY, width=0.5)
            elif c == 'P':
                xhead(pg, hx, hy, 5.2 * k)
            else:
                head(pg, hx, hy, 5.2 * k, filled=value != 2)
            heads.append((hx, hy, c))
        # stems up to the beam line; beams per group (grouping counted in cells)
        stem_x = []
        for hd in heads:
            if hd is None:
                stem_x.append(None)
                continue
            hx, hy, c = hd
            sx = hx + 3.0 * k
            line(pg, (sx, hy - 0.4 * k), (sx, beam_y), 0.7)
            stem_x.append(sx)
        nbeams = {16: 2, 8: 1}.get(value, 0)
        start = 0
        for g in groups:
            idx = [j for j in range(start, min(start + g, n)) if stem_x[j] is not None]
            start += g
            if nbeams == 0 or not idx:
                continue
            for b in range(nbeams):
                by = beam_y + b * 3.2 * k
                if len(idx) == 1:
                    j = idx[0]
                    flag(pg, stem_x[j], beam_y + b * 3.2 * k, 4.4 * k, True, 1)
                    continue
                pg.draw_rect(fitz.Rect(stem_x[idx[0]], by, stem_x[idx[-1]], by + 1.9 * k), color=INK, fill=INK, width=0)
        for i, c in enumerate(cells):
            if c == '':
                rest(pg, gx + i * cw + cw / 2, hi_y - 2 * 4.5 * k + line_gap / 2, 4.5 * k, value and 16 // value)
        # syllables
        syl_y = lo_y + 4 * k + syl_h * 0.8
        for i, c in enumerate(cells):
            s = SYLL.get(c, c)
            if not s:
                continue
            fnt = 'B' if c not in ('-', '') else 'R'
            sz = 6.6 * k
            sw = text_w(s, fnt, sz)
            pg.insert_text((gx + i * cw + cw / 2 - sw / 2, syl_y), s, fontname='OS' + fnt, fontsize=sz,
                           color=INK if fnt == 'B' else GREY)
    return h, draw


def wrap_text(text, font, size, maxw):
    words, out, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if text_w(t, font, size) <= maxw or not cur:
            cur = t
        else:
            out.append(cur); cur = w
    if cur:
        out.append(cur)
    return out


def rhythm_text_lines(r, maxw, k):
    """Left column of the rhythm box: (text, font, size, line advance)."""
    out = [(f"RHYTHM  ·  {r.get('instrument_short', 'FRAME DRUM')}", 'S', 8 * k, 8 * k * 1.7)]
    out.append((r['name'], 'B', 11.5 * k, 11.5 * k * 1.3))
    meta = '   '.join(v for v in (r.get('meter'), r.get('grouping') and f"({r['grouping']})", r.get('tempo')) if v)
    for s in wrap_text(meta, 'R', 9 * k, maxw):
        out.append((s, 'R', 9 * k, 9 * k * 1.4))
    for key in ('practice_text', 'confidence_text'):
        if r.get(key):
            for s in wrap_text(r[key], 'I', 7.6 * k, maxw):
                out.append((s, 'I', 7.6 * k, 7.6 * k * 1.38))
    return out
