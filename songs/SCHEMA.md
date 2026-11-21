# Song JSON (schema `ethno-song/1`) and the two-page layout

Written 21.11.2026 so a Swift app can read the same JSON and draw the same pages as `tools/render_pdf.py`.
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
| `tempo` | string | Free text, e.g. `"~99 BPM"`. |
| `rhythm` | string | Free text, e.g. `"2+3 (5/8)"`, `"Malfouf"`. |
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
   If wider than 487.28 − 110 it shrinks proportionally (never below 62 %).
2. Page tag right-aligned at x = 541.28 on the title baseline: `FOR SINGERS` / `FOR GUITAR`, S 9, labels colour.
3. Subtitle: R 10, `#666666`, y = title + 16.
4. Info line: `Key <key>   ·   Tempo <tempo>   ·   Rhythm <rhythm>` (parts left out when empty), R 9.5, `#666666`, y = subtitle + 14.
5. Rule 0.6 pt `#D0D0D0` from x 54 to 541.28 at y = info + 10. Content starts at rule + 18.

### Footer (both pages)

`ETHNO-HRVATSKA  ·  <number> <title>  ·  singers|guitar  ·  1/2|2/2`, R 7.5, `#B0B0B0`, centred, y = 841.89 − 28 = 813.89.

### Page 1, singers

Two text columns of 232.64: lyric at x = 54, translation at x = 54 + 232.64 + 22 = 308.64, same baseline.
At scale k (start 1.00, step −0.02, lowest 0.70, the first k where everything fits above y = footer − 18):

- Section label: name in UPPERCASE, S 8k, labels colour; advance 8k × 1.9.
- Line: baseline = line top + 12.5k. Lyric R 12.5k ink; repeat mark S 10k labels colour, 6 pt after the lyric; translation I 10.5k `#6A6A6A`.
  Advance 12.5k × 1.42 per line. After a section: 9k.
- A lyric or translation wider than its column shrinks alone (proportional, never below 62 % of its size).

### Page 2, guitar

Layout search, first fit wins: one column (width 487.28) at k = 1.00, 0.98 … 0.92; then two columns at k = 1.00 … 0.76.
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

## 4. Pipeline (what the Swift app re-implements)

1. Read `songs/*.json` (or edit and save them; the `.cho` sources are a convenience for people).
2. For each song draw page 1 and page 2 with the numbers above, into `PDFs/<nn> <Title>.pdf`.
3. Measure text with the same Open Sans files (CoreText `CTLineGetTypographicBounds` gives the advance width) so chord x matches.

The audio side (stems, chroma, basic-pitch) is offline research, not part of the app; its results are already in the JSON.
