# Song JSON (schema `ethno-song/1`) and the two-page layout

Written 21.11.2026 so a Swift app can read the same JSON and draw the same pages as `tools/render_pdf.py`.
Extended 21.11.2026 (evening): `melody` (staff at the top of page 1, section 5) and `rhythm` as an object (frame-drum box at the
top of page 2, section 6); singers page two-column fallback; guitar page three-column fallback.
The Python renderer is the reference: when this text and the code disagree, the code wins and this file is fixed.

## 1. Files

- `songs/src/<nn>-<slug>.cho` is the hand-written source (ChordPro-like, see `tools/cho2json.py`).
- `songs/<nn>-<slug>.json` is generated from it with `python3 tools/cho2json.py`. Apps read only the JSON.
- `songs/evidence/<nn>-<slug>.analysis.json` holds the audio-analysis numbers behind the chords (not needed to draw).
- `PDFs/<nn> <Title>.pdf` is the output (A4, two pages).

## 2. JSON fields

| Field | Type | Meaning |
|---|---|---|
| `schema` | string | Always `"ethno-song/1"`. |
| `number` | string | Two digits, `"01"`..`"05"`. Used in the title and the file name. |
| `slug` | string | ASCII file slug, e.g. `"da-bi-nasi-starci-znali"`. |
| `title` | string | Song title, original spelling with diacritics (NFC). |
| `subtitle` | string | Origin and arrangement, one line. |
| `language` | string | Language of the lyrics. |
| `key` | string | Free text, e.g. `"G minor"`, `"D minor · Maqam Bayati on D"`. |
| `tempo` | string | Free text, e.g. `"♩ ≈ 95"`, `"♪ ≈ 190"` (♩ ♪ are drawn from Apple Symbols, see 3). |
| `rhythm` | object (since 21.11.2026; older files: string) | The official rhythm for the frame drum, MPA Academy conventions. Fields in section 6. Never Marko's private shorthand. |
| `melody` | object, optional (since 21.11.2026) | The vocal line of one stanza as staff notation. Fields in section 5. |
| `scale` | string, optional | Scale notes when they matter (maqam). Not drawn. |
| `confidence` | string | Honest chord confidence for the whole song. Not drawn. |
| `chord_source` | `"board"` or `"audio"` | Where the song's confirmed chords come from. |
| `play` | array of `{label, chords}` | Instrumental rows drawn at the top of the guitar page (intro, special instrumental). `chords` is plain text. |
| `sections` | array of `{name, lines}` | Stanzas in singing order. `name` is drawn as a small label (may be `""`). |
| `sections[].lines[]` | `{text, translation, repeat, chords}` | One sung line. |
| `text` | string | The lyric line, exactly as in Pjesme tekstovi.pdf (NFC). |
| `translation` | string | English translation of this line. |
| `repeat` | string or null | Repeat mark drawn after the line, e.g. `"×2"`. |
| `chords[]` | `{at_char, chord, source, confirmed}` | Chords of this line, ascending `at_char`. |
| `at_char` | integer | Index into `text` counted in Unicode scalars (Swift: `text.unicodeScalars`, Python: `str` index), after NFC. The chord sounds at that character. `at_char == text.count` means after the last word. |
| `chord` | string | Chord name in English notation: `Am`, `Bb`, `E7`, `Em7` (the boards' Croatian H = B, B = Bb, A# = Bb are converted). |
| `source` | `"board"`, `"audio"`, `"inferred"` | Board = written on the rehearsal flipchart; audio = from the recording analysis; inferred = copied by analogy. |
| `confirmed` | bool | `false` draws the chord grey. True only for chords from the song's `chord_source`. |
| `arrangement` | array of string | The form, one step per entry (drawn as FORM at the bottom of the guitar page). |
| `notes` | array of string | Drawn in italics under FORM. |
| `evidence` | array of string | How the chords were found. Not drawn. |
| `uncertain` | array of string | What still needs Marko's ear. Not drawn (collected in `songs/UNCERTAIN.md`). |
| `sources` | `{lyrics, images[], audio}` | Source files (images are in `source/images/`). |

## 3. Page and type (all values in PostScript points, 1 pt = 1/72 in)

- Page A4 portrait: 595.28 × 841.89. Margins: left 54, right 54, top 54, bottom 48. Content width 487.28.
- Column gutter 22. Two-column width = (487.28 − 22) / 2 = 232.64.
- Fonts (in `fonts/`, Apache 2.0): Open Sans Regular (R), Italic (I), Semibold (S), Bold (B).
- Colours: ink `#111111`, subtitle/info `#666666`, translation `#6A6A6A`, labels `#A0A0A0`, rules `#D0D0D0`,
  chord `#B03A2E`, unconfirmed chord `#A8A8A8`, footer `#B0B0B0`.

y grows downwards from the top edge; every `y` below is a text baseline.

### Header (both pages)

1. Title `"<number>  <title>"` (two spaces), B 22, ink, x = 54, y = 54 + 22 × 0.9 = 73.8.
   If wider than 487.28 it shrinks proportionally (never below 62 %).
2. No page tag (Marko, 21.11.2026: no "FOR SINGERS" / "FOR GUITAR", nothing saying who the page is for).
3. Subtitle: R 10, `#666666`, y = title + 16.
4. Info line: `Key <key>   ·   Tempo <tempo>   ·   Rhythm <rhythm text>` (parts left out when empty), R 9.5, `#666666`, y = subtitle + 14.
   Rhythm text = `rhythm.name`, then ` <meter>` unless the name already contains it, then ` (<grouping>)` when the grouping
   is not empty: `Malfouf 2/4 (3+3+2)`, `Aksak 5/8 (2+3)`, `Huayno 2/4`.
   The characters ♩ (U+2669) and ♪ (U+266A) are not in Open Sans: every text run drawn by the renderer switches to the macOS
   font Apple Symbols for them, at 1.25 × the size, same baseline (also in widths).
5. Rule 0.6 pt `#D0D0D0` from x 54 to 541.28 at y = info + 10. Content starts at rule + 18.

### Footer (both pages)

None (Marko, 21.11.2026: "no footers at all"). The name `footer` below means only the layout limit y = 841.89 − 28 = 813.89:
content is laid out above footer − 18 (page 1) / footer − 16 (page 2) exactly as before.

### Page 1, singers

Content top y0 (header rule + 18). If the song has `melody`, the MELODY block (section 5) is drawn at (54, y0), full width
487.28, and the lyrics start at y0 + melody height + 14.
Layout search, first fit wins, available height = (footer − 18) − lyrics top:
(a) side by side, one column, k = 1.00, 0.98 … 0.80; (b) stacked, two columns of 232.64, k = 1.00 … 0.70.

(a) Side by side: two text columns of 232.64: lyric at x = 54, translation at x = 54 + 232.64 + 22 = 308.64, same baseline.

- Section label: name in UPPERCASE, S 8k, labels colour; advance 8k × 1.9.
- Line: baseline = line top + 12.5k. Lyric R 12.5k ink; repeat mark S 10k labels colour, 6 pt after the lyric; translation I 10.5k `#6A6A6A`.
  Advance 12.5k × 1.42 per line. After a section: 9k.
- A lyric or translation wider than its column shrinks alone (proportional, never below 62 % of its size).

(b) Stacked (long songs, e.g. Dremle mi se): one block per line, flowing from column 1 into column 2 at line granularity
(balanced, see Packing). Per line: section label on the first line of a section (S 8k, advance 8k × 1.9); lyric R 12.5k,
baseline = line top (+ label) + 12.5k; translation I 9.975k (= 10.5k × 0.95) `#6A6A6A`, baseline = lyric baseline + 9.975k × 1.25;
line advance = 12.5k × 1.18 + 9.975k × 1.25 + 2.5k; after the last line of a section 7k more. Repeat mark as in (a).

### Packing (both pages)

Blocks keep their order. For n columns the column height target starts at max(total / n, tallest block) and grows in 2 pt
steps; a column is closed when the next block would pass the target; the first target that needs at most n columns wins
(it must stay ≤ the available height, else this k fails).

### Page 2, guitar

Content top y0. If `rhythm` is an object, the RHYTHM box (section 6) is drawn at (54, y0) and the page continues at
y0 + box height (the box height includes its legend, rule and the 14 pt gap).
Layout search, first fit wins: one column (width 487.28) at k = 1.00, 0.98 … 0.92; then two columns at k = 1.00 … 0.76;
then three columns (width (487.28 − 2 × 22) / 3 = 147.76) at k = 1.00 … 0.70.
Available height = (footer − 16) − content top − play block − form block − 10.

- Play block (top, full width): per row `"<label>:"` S 9.5k `#666666`, then 6 pt, then the chord text B 9.5k chord colour;
  row advance 9.5k × 1.55; block height rows × that + 8k.
- Lines flow from column 1 into column 2 at line granularity; the split is the one that makes the taller column shortest.
  A section label rides on the first line of its section.
- Per line (top to bottom): label (if first line) advance 8k × 1.9; chord row (only if the line has chords) advance 10.5k × 1.08;
  lyric advance 12k × 1.14; translation advance 8.8k × 1.25 (only the first time this exact lyric text appears in the song;
  repeated lines show no translation, the singers page has them all); gap 2.5k; after the last line of a section 7k more.
- Lyric baseline = line top + chord row + 12k × 0.95. Chord baseline = lyric baseline − 12k × 1.06. Translation baseline = lyric baseline + 8.8k × 1.25.
- Lyric R 12k ink (shrinks alone if wider than column − repeat − 30). Chords B 10.5k, chord colour or grey when `confirmed` is false.
  Translation I 8.8k `#6A6A6A`.
- **Chord placement rule.** x = column x + advance width of `text[0..<at_char]` in the lyric font at the lyric's drawn size
  (kerning as the font gives it). If `at_char == text.count`, add 0.35 × lyric size. Then, left to right, each chord's x is pushed to at least
  the previous chord's right edge + 5 pt, so names never touch. Chords are never moved left.
- Form block (bottom, full width, size 8.5 × min(1, k + 0.05)): a 0.6 pt rule 2 pt above it; `FORM` S labels colour;
  the arrangement as bullets `•  ` in two columns of 232.64 (left column takes the first half, a wrapped bullet is never split);
  then the notes in I, full width; line advance size × 1.38; plus 8k. If any chord is unconfirmed, the first note line is
  "Grey chords are not on the board or not confirmed by the recording: check them by ear."
  The block's bottom sits at footer − 16.

## 5. The MELODY block (page 1, top; `tools/notation.py` `layout_melody`)

### JSON `melody`

| Field | Meaning |
|---|---|
| `status` | `"draft"` (transcribed from the recording, to be confirmed by Marko) or `"not_transcribed"` (no `systems`: one empty staff is drawn to write in by hand). |
| `label` | Drawn after `MELODY  ·  `, e.g. `"stanza 1  ·  draft from the recording, to be confirmed by Marko"`. |
| `section`, `lines` | Which stanza and lines the staff carries (information). |
| `clef` | `"treble"`, or `"treble8"` for a male voice (G clef with a small 8 below; written an octave higher than sung). |
| `key_signature` | `{fifths, half_flats}`: fifths > 0 sharps, < 0 flats; `half_flats` letters drawn after them as half-flats (Bayati: `fifths -1`, `half_flats ["E"]`). |
| `time` | `"2/4"`, `"3/4"`, `"5/8"` … ; `grouping` (`"2+3"`) sets the beams in x/8. |
| `tempo`, `confidence`, `source` | Information (not drawn; the tempo is in the header). |
| `systems` | Array of staff lines; each an array of notes `{pitch, len, syllable, chord?, tie?}`. |
| `pitch` | `"E4"`, `"F#4"`, `"Bb3"`, `"Ed4"` (E half-flat), `"Bn4"` (natural), `"R"` (rest). Sounding pitch (for treble8 the renderer adds an octave). |
| `len` | Length in sixteenths: 1, 2, 3 (dotted 8th), 4, 6 (dotted quarter), 8, 12 (dotted half), 16. The total is a whole number of bars. |
| `syllable` | Text under the note; ending in `-` = a hyphen is drawn before the next syllable. Empty for a tied note. |
| `chord` | Chord name drawn above this note. `tie: true` ties the note to the previous one. |

### Layout (sp = staff space = 5.6 pt at scale 1; all values in sp unless pt)

- Label: `MELODY  ·  <label>` S 8 pt `#A0A0A0`, baseline = block top + 8 pt; shrinks to fit 487.28 (never below 62 %). Advance 15.2 pt.
- Each system: chord row, staff, syllable row. Five lines 0.5 pt, 1 sp apart, from x = 54 to 541.28; a 0.6 pt line closes the left end.
  Staff position p: 0 = bottom line (E4 in treble), one step = half a space; y = bottom line − p × sp / 2.
- Vertical: let hi = max(8, note p, p + 7 for notes with p < 4), lo = min(0, note p, p − 7 for notes with p ≥ 4).
  above = (hi − 8) × sp/2 + 1.0 sp; below = (0 − lo) × sp/2 + 0.8 sp; chord size c = 9.5 pt; lyric size l = 9.5 pt.
  Staff top line = system top + c + max(above, 1.2 sp) + 0.2c. Chord baseline = system top + c.
  Syllable baseline = staff top + 4 sp + max(below, 1.0 sp) + l. System height = syllable baseline − system top + 0.9 l + 4 pt.
  Block height = 15.2 pt + Σ system heights + 6 pt; then 14 pt gap before the lyrics.
- Prefix (x from 54): G clef (Apple Symbols U+1D11E) at x + 0.6 sp, size 7.4 sp, baseline = bottom line + 1.15 sp; for treble8 a
  digit 8 (R 1.7 sp) at clef x + 1.15 sp, baseline bottom line + 2.9 sp. Key signature from clef x + 3.9 sp, one sign per 1.3 sp,
  then 0.8 sp (0.4 sp when there is none). Sharps F C G D A E B on p 8 5 9 6 3 7 4; flats B E A D G C F on p 4 7 3 6 2 5 1;
  half-flats on the flat positions. Accidentals: Apple Symbols ♭ ♯ ♮ at 3.4 sp, left edge x, baseline = note y + 0.45 sp (♭) /
  1.05 sp (♯ ♮); a half-flat is the ♭ plus a 0.7 pt slash from (x − 0.15, y − 1.05) to (x + 1.05, y − 1.75) sp.
  Time signature (first system only): numerator and denominator B 2.75 sp, centred at key end + 1.3 sp, baselines staff top + 2 sp
  and + 4 sp; then 3.6 sp. Prefix width = 0.6 + 3.9 + key + (3.6 on the first system) sp.
- Horizontal: each note's natural width = max((2.2 + 1.5 √(len/2)) sp, syllable width + 0.9 sp, chord width + 0.8 sp)
  + 1.6 sp if it shows an accidental; a bar line (1.4 sp) after every full bar. All widths are multiplied by
  (487.28 − prefix) / Σ natural widths, so every system is justified. Head centre = element left (+ 1.6 sp with accidental) + 0.95 sp.
  An accidental is shown when the pitch's accidental differs from the key signature (a natural sign when the key has one and the
  pitch has none). The last bar line of the last system is a final double bar (thin 0.6 pt, thick 2.0 pt at the right edge).
- Heads: ellipse 1.30 × 0.92 sp turned −20°, filled for len < 8, hollow (outline 0.21 sp) for 8 and more. Dot (len 3, 6, 12):
  radius 0.2 sp at head x + 1.15 sp, half a space up when the head sits on a line. Ledger lines 0.6 pt, 2.1 sp wide, for p ≤ −2
  and p ≥ 10 (every even position).
- Stems 0.75 pt, 3.5 sp; up (at head x + 0.6 sp) when p < 4, else down (at head x − 0.6 sp). Notes shorter than a quarter are
  beamed inside one beat (x/4: each quarter; x/8: the grouping); a beamed group takes the direction of its mean p; the beam is
  horizontal, 0.5 sp thick, 3.5 sp beyond the furthest head; sixteenths get a second beam 0.8 sp inside (a lone sixteenth
  a 1.2 sp stub). A lone eighth / sixteenth gets one / two curved flags. Ties: a curve under (stem up) or over the heads, depth 0.9 sp.
- Chord names B 9.5 pt `#B03A2E` at head x − 0.65 sp on the chord baseline. Syllables R 9.5 pt ink, centred under the head;
  a hyphen centred in the gap between a syllable ending in `-` and the next one (only if the gap is wider than the hyphen + 1 pt).
- `not_transcribed`: one system with clef, key, time and three bar lines splitting the rest of the width in four empty bars.

## 6. The RHYTHM box (page 2, top; `tools/notation.py` `layout_rhythm`)

### JSON `rhythm`

| Field | Meaning |
|---|---|
| `name` | Official name: `"Malfouf"`, `"Aksak 5/8"`, `"Triple meter"`, `"Huayno"`. |
| `instrument` | `"Frame drum (bendir, daf, riq)"`. The box says FRAME DRUM. |
| `meter`, `grouping` | Time signature and its groups (`"3+3+2"` in cells; may be empty). |
| `cell` | Note value of one cell: 16, 8 or 4. The cells fill exactly one bar. |
| `tempo` | `"♩ ≈ 95"`. |
| `cells` | MPA Academy strokes, one per cell: `D` Dum, `T` Tak, `K` Ka, `P` Pa, `-` touch (ghost note, a sound), `""` silence. |
| `syllables` | Spoken names: DUM, TAK, KA, PA, `–` (touch), `""`. |
| `events` | One per cell `{beat, value, stroke, syllable, accent}`: beat counted in quarter notes from 1 (16ths: 1, 1.25 …), value `"1/16"`, accent = D T K P. |
| `mpa` | The MPA Academy Lab item it matches (e.g. `TR04 Malfuf / Wahda (8/16): D - - T - - T -`). Not drawn. |
| `practice` | MPA practice with PA in place of TAK (`D - - P - - P -`), drawn as one line. |
| `confidence` | `"confirmed by the recording ..."` or `"... to be confirmed by the professor"`; drawn. |
| `evidence` | The measurement behind it. Not drawn. |

### Layout (k = 1; x0 = 54, width 487.28)

- Left text column, width 168: lines with their advance: `RHYTHM  ·  FRAME DRUM` S 8 `#A0A0A0` (13.6); name B 11.5 ink (14.95);
  `<meter>   (<grouping>)   <tempo>` R 9 `#666666` (12.6, wrapped at 158); then `MPA practice: D – – P – – P – (PA in place of TAK)`
  and the confidence (first letter upper-case, full stop), I 7.6 `#666666` (10.49 per wrapped line). Each baseline = top of its line
  + advance × 0.72.
- Notation area: gx = x0 + 168 + 22 (22 = room for the drum clef and time signature). Cell width cw = min(30, (487.28 − 190) / n).
- Cells row (MPA Lab look): top = box top + 7; boxes cw × 15, 0.6 pt ink; an accent cell (D T K P) has a filled 2.4 pt bar on its
  left edge; the letter S 10.5 centred (+0.8 pt right on accents), `–` grey for a touch, nothing for silence. Cell numbers 1…n,
  R 6 `#A0A0A0`, baseline = cells top − 1.8. Spoons under the cells, baseline = cells bottom + 7.5: restart at 1 on every
  accent, count on through touches and silences; the 1 is B 7 ink, the others R 7 `#A0A0A0`.
- Drum staff: high line (TAK, KA, PA: edge) at y = cells bottom + 9 + 3 + 14; low line (DUM: centre) 9 pt below; 0.6 pt, from
  gx − 20 to gx + n·cw. Percussion clef = two filled bars 1.6 × (line gap + 4) at gx − 20 + 1.5 and + 4.7. Time signature
  B 7.5 centred at gx − 20 + 11.5: numerator baseline = high line − 0.6, denominator baseline = low line + 5.8.
  Repeat end at the right: thin line at −3.2, thick bar 1.6 wide at the end, two dots r 0.9 at −6, between the lines.
- Notes at the cell centres: D = filled head on the low line; T, K = filled head on the high line; P = x head on the high line;
  touch = small head (0.62 of size) on the high line between grey round brackets; silence = a rest. Head size: the melody head
  with sp = 5.2 (hollow when the cell is a half note). Stems 0.7 pt at head x + 3.0 up to the beam line = high line − 13.
  Beams per group of the grouping (in cells; per quarter-note beat when the grouping is empty or does not add up): 16ths two
  beams 1.9 thick 3.2 apart, 8ths one, quarters none; a group of one cell gets a flag.
- Syllables under the staff, baseline = low line + 4 + 8: DUM TAK KA PA in B 6.6 ink, `–` R 6.6 grey, centred on the cell.
- Box height = max(notation 71 = 7 + 15 + 9 + 3 + 14 + 9 + 4 + 10, text column) + 4. Under the box: the legend, R 6.8 `#A0A0A0`, wrapped at 487.28, advance 9.18:
  "Frame drum staff: low line DUM (centre of the skin), high line TAK and KA (edge), x = PA, small note in ( ) = touch (ghost note).
  Cells as in MPA Academy: thick left line = accent, numbers under the cells restart on every accent." Then a 0.6 pt rule
  6 pt below the legend, then 14 pt gap.

## 7. Pipeline (what the Swift app re-implements)

1. Read `songs/*.json` (or edit and save them; the `.cho` sources are a convenience for people).
2. For each song draw page 1 and page 2 with the numbers above, into `PDFs/<nn> <Title>.pdf`.
3. Measure text with the same Open Sans files (CoreText `CTLineGetTypographicBounds` gives the advance width) so chord x matches.
4. Draw the staff and drum notation with paths (CGContext lines, ellipses, curves); the G clef, ♭ ♯ ♮ and ♩ ♪ come from the
   system font "Apple Symbols" (present on every Mac), everything else from Open Sans.

The audio side (stems, chroma, basic-pitch) is offline research, not part of the app; its results are already in the JSON.
