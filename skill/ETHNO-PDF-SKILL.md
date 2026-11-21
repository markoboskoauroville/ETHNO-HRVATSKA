---
name: ethno-song-pdf
description: Make or update the Etno orkestar / ETHNO-HRVATSKA song PDFs in ONE simple style - page 1 for singers (original lyrics + English translation), page 2 for the guitarist (chords above the words + translation), from the lyric sheet, the rehearsal flipchart photos and the recording (stems + chord analysis). Use for ANY ethno song sheet, "Pjesme tekstovi", lyric/chord PDF, Wein aa Ramallah / Preli prelo / Da bi naši starci znali / Dremle mi se / Rosaura Lindaura task, or a new song for the Etno orkestar.
---

# Etno orkestar song PDFs (simple format, since 21.11.2026)

Replaces the old create-pdf-skills.md of 19.11.2026. Since 21.11.2026 (evening) each sheet carries notation again, in two fixed
places: a MELODY staff at the top of page 1 and a frame-drum RHYTHM box at the top of page 2 (Marko: "I need a staff at the top.
There is a melody line and lyrics" and "make official rhythm notes any percussionist can understand, not my own things").
Repo: github.com/markoboskoauroville/ETHNO-HRVATSKA (local ~/Developer/ETHNO-HRVATSKA). Marko's folder: ~/Documents/ETHNO-HRVATSKA.

## The format (one style for every song)

- No page tags ("FOR SINGERS" / "FOR GUITAR") and no footer line on any page (Marko, 21.11.2026): page 1 is the singers', page 2 the
  guitarist's and percussionist's without saying so.
- **Page 1 (singers)**: `<nn>  <Title>`, subtitle, key/tempo/rhythm line, the MELODY staff (one stanza: clef, key signature with
  half-flats for maqam, time signature from the rhythm work, chords above, syllables under the notes), then every stanza: original
  lyrics left, English translation right on the same line (long songs: two columns, translation under the line), repeat marks (×2).
- **Page 2 (guitar, frame drum)**: same header; the RHYTHM box (frame drum); instrumental rows (intro, special instrumental); every lyric line with its chords
  directly above the syllable where the chord changes, the translation small under it (once per distinct line); FORM (arrangement)
  and short notes at the bottom. Grey chord = not on the board / not confirmed: Marko checks it by ear.
- A4 portrait, Open Sans (in the repo `fonts/`), white page, red chords `#B03A2E`. Exact numbers: `songs/SCHEMA.md`.
- File name `<nn> <Title>.pdf` in `~/Documents/ETHNO-HRVATSKA/PDF/`; older versions are moved to `PDF/old/`, never deleted.

## Rhythm: official notation only (MPA Academy conventions)

- Never Marko's private shorthand on a sheet ("12|123", "123 ja ostajem", "TILILILI ritam MAFOUF", MARKO-BEAT.txt): those notes are
  evidence for us; the sheet gets the official rhythm. Marko is the MPA Academy professor (skill mpa-academy, ~/Developer/MPA):
  write rhythms the way the academy does.
- MPA conventions: strokes **D** Dum, **T** Tak, **K** Ka, **P** Pa (capital = one stroke), **-** touch / ghost note (a sound),
  empty = silence; an accent is any stroke but the touch and silence (thick left line on the cell); the spoons under the cells
  restart at 1 on every accent (so D - D - - shows 1 2 1 2 3); MPA practice plays every rhythm again with PA in place of TAK.
  MPA Lab rhythms (lessons/traditional-rhythms.mjs): Malfuf / Wahda TR04 = D - - T - - T - (8 sixteenths, 2/4, 3+3+2),
  Maqsum TR01 = D T - T D - T -, Baiduska TR13 = D - T - - (2+3), Tik TR12 = D - - T - (3+2) ...; use their cells when the song
  uses that rhythm.
- The box (page 2) shows: name, meter, grouping, tempo, the MPA practice line, the confidence; the MPA cell grid (numbers above,
  spoons below); a two-line frame-drum staff under it (low line DUM = centre, high line TAK/KA = edge, x = PA, touch = small note in
  brackets, stems up, beams per group, repeat sign); DUM/TAK syllables under. A legend line says it is for frame drum.
- Find the meter on the recording, never from the beat tracker alone (its BPM was a sub-pulse in every song):
  `python3 tools/analysis/rhythm_check.py <drums.wav> <start> <dur> <pulse>` prints the autocorrelation lags and the gaps between
  Dum strokes in pulses (Malfouf 3 3 2, 2+3 aksak 2 3 alternating, 3/4 multiples of 3). Tag each rhythm "confirmed by the
  recording" or "to be confirmed by the professor" (in `{rhythm_confidence:}`), with the numbers in `{rhythm_evidence:}`.
- Directives: `{rhythm: Name}` `{rhythm_meter:}` `{rhythm_grouping:}` `{rhythm_cell: 16|8|4}` `{rhythm_cells: D - - T - - T -}`
  (`.` = silence) `{rhythm_tempo: ♩ ≈ 95}` `{rhythm_mpa:}` `{rhythm_practice:}` `{rhythm_confidence:}` `{rhythm_evidence:}`.

## Melody staff

- One stanza (or its first lines), transcribed from the vocal stem: `python3 tools/analysis/melody_plot.py <vocals.wav> <drums.wav>
  <start> <end> <tuning cents> out.png`, LOOK at the picture, write the syllables as tokens, quantise to the meter found above.
- `{melody_info: label=...; section=1; lines=1-2; clef=treble|treble8; fifths=-1; half_flats=E; time=2/4; tempo=...; status=draft;
  confidence=...; source=...}` and one `{melody: [Em]E4:1:Pre- E4:1:li ... | [Em]E4:2:lo- E4:6:ga}` per staff line (LEN in
  sixteenths; `-` after a syllable = hyphen; `~` before a pitch = tie; `|` bar lines are checked).
- Male voice: clef treble8 with the sounding pitches. Bayati: key signature `fifths=-1; half_flats=E`.
- If the voice cannot be followed on the recording, `status=not_transcribed`: an empty staff with clef, key and time is drawn and
  the label says why. Never invent a melody; every draft says "to be confirmed by Marko" and goes into songs/UNCERTAIN.md.

## Sources and who wins

1. **Words**: `Pjesme tekstovi.pdf` (Marko, 21.11.2026: authoritative). Copy each line exactly (punctuation too); a check script
   compares every JSON line to it.
2. **Chords and form**: the flipchart photos (HEIC/JPEG). Croatian names: H = B, B = Bb, A# = Bb, lowercase e/a = Em/Am.
   On the Rosaura board chords are written UNDER the syllable; on the others above.
3. **Audio** confirms or fills: what the board does not say is marked `[~X]` (inferred) or `[^X]` (from audio) and drawn grey.
4. Uncertain words or meanings go into the song's `{uncertain: ...}` lines (and `songs/UNCERTAIN.md`), never invented.

## Steps

1. Write or edit `songs/src/<nn>-<slug>.cho`: directives `{title:}` `{key:}` `{tempo:}` `{rhythm:}` `{chord_source: board|audio}`
   `{play: Label || chords}` `{arr:}` `{note:}` `{evidence:}` `{uncertain:}` `{section:}`, lines
   `[Am]lyric [C]words || translation || ×2`. A chord after the last word: `ja. [Am]`.
2. `python3 tools/cho2json.py` -> `songs/*.json`.
3. `python3 tools/render_pdf.py --png /tmp/x` -> `PDFs/`. LOOK at every PNG: nothing cut, chords over the right syllable,
   notes on the right lines (zoom with `get_pixmap(dpi=300, clip=...)`), guitar page readable (two columns down to 0.76, then three).
4. Copy the PDFs into `~/Documents/ETHNO-HRVATSKA/PDF/` (overwrite; the earlier set is in `PDF/old/` and git), commit and push main
   (`git pull --rebase` first: the Swift app is built in the same repo).

## Audio analysis (only when chords must be confirmed)

- Stems: Demucs `htdemucs` 4-stem (model cached in ~/.cache/torch) -> other, bass, vocals, drums. Vocals also via DaVinci Resolve:
  import the m4a, timeline per clip, `Timeline.SetVoiceIsolationState(1, {isEnabled: True, amount: 100})`, render MOV H264 with
  ExportVideo False, AudioCodec lpcm, then ffmpeg to WAV. (WAV is not a render format in Resolve 21; Music Remixer stems are not scriptable.)
- `tools/analysis/analyze.py <mix> <stemdir> out.json`: tempo, key, chroma path.
  `tools/analysis/restricted.py <stemdir> <vocal.wav> <window_s = 2 beats> <board vocabulary> out.json [--drone]`: best chord per window
  within the board's chords plus the free best chord; `--drone` subtracts the median chroma (songs on a drone, e.g. Da bi naši starci znali).
- basic-pitch (`~/.pyenv/shims/basic-pitch out/ other.wav`) on the other stem -> MIDI -> pitch-class weights (key, scale, Dorian vs minor).
- Whisper (the :8837 voice API) cannot transcribe these sung rehearsal takes (returns "thanks for watching" hallucinations): do not use it for lyrics.
- Write the numbers into `songs/evidence/<song>.analysis.json` and one-line conclusions into `{evidence:}`.

## Teach and close

- Every correction Marko gives about a song goes into its `.cho`, and a rule goes here.
- Register changes in ~/Downloads/API/PROJECTS.md (dated). Compiling a Swift app is GitHub Actions only, never on the Mac.

## The Mac app (21.11.2026)

`/Applications/Ethno Song Sheets (Mantra).app` (repo app/, built by GitHub Actions only) does the same workflow natively: song library, editor with chords above syllables, image and recording import, Vision OCR draft, optional Analyse, PDF render in Swift per songs/SCHEMA.md, preview, Reveal in Finder. Test hooks: `--library DIR --render-all OUT` and `--shot FILE [--song NN] [--preview]`.
