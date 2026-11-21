---
name: ethno-song-pdf
description: Make or update the Etno orkestar / ETHNO-HRVATSKA song PDFs in ONE simple style - page 1 for singers (original lyrics + English translation), page 2 for the guitarist (chords above the words + translation), from the lyric sheet, the rehearsal flipchart photos and the recording (stems + chord analysis). Use for ANY ethno song sheet, "Pjesme tekstovi", lyric/chord PDF, Wein aa Ramallah / Preli prelo / Da bi naši starci znali / Dremle mi se / Rosaura Lindaura task, or a new song for the Etno orkestar.
---

# Etno orkestar song PDFs (simple format, since 21.11.2026)

Replaces the old create-pdf-skills.md of 19.11.2026 (staff notation, two-column reference sheet). No notation any more.
Repo: github.com/markoboskoauroville/ETHNO-HRVATSKA (local ~/Developer/ETHNO-HRVATSKA). Marko's folder: ~/Documents/ETHNO-HRVATSKA.

## The format (one style for every song)

- **Page 1, FOR SINGERS**: `<nn>  <Title>`, subtitle, key/tempo/rhythm line, then every stanza: original lyrics left, English translation
  right on the same line, repeat marks (×2) after the line, small section labels. Nothing else.
- **Page 2, FOR GUITAR**: same header; instrumental rows (intro, special instrumental) at the top; every lyric line with its chords
  directly above the syllable where the chord changes, the translation small under it (once per distinct line); FORM (arrangement)
  and short notes at the bottom. Grey chord = not on the board / not confirmed: Marko checks it by ear.
- A4 portrait, Open Sans (in the repo `fonts/`), white page, red chords `#B03A2E`. Exact numbers: `songs/SCHEMA.md`.
- File name `<nn> <Title>.pdf` in `~/Documents/ETHNO-HRVATSKA/PDF/`; older versions are moved to `PDF/old/`, never deleted.

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
   guitar page readable (the renderer goes to two columns, never below scale 0.76).
4. Copy the PDFs into `~/Documents/ETHNO-HRVATSKA/PDF/` (old ones to `PDF/old/`), commit and push main.

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
