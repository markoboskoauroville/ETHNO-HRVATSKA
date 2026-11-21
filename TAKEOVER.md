# ETHNO-HRVATSKA: takeover

Song sheets for Marko's Etno orkestar (five songs of the autumn 2026 rehearsals). Started 19.11.2026 as single
reference sheets with notation; rebuilt 21.11.2026 in one simple two-page format (Marko: "Pjesme tekstovi.pdf" holds
the lyrics of all songs; page 1 for singers, page 2 for the guitarist, very simple).
Public repo without README or description (MANTRA_MANIFEST modules/repo-privacy.md: unpromoted). Branch: main only.

## What is here

| Path | What |
|---|---|
| `songs/src/*.cho` | Hand-written song sources: lyrics, chords, translation, form, evidence, doubts. Edit these. |
| `songs/*.json` | Generated song data (schema `ethno-song/1`), the input of every renderer. |
| `songs/SCHEMA.md` | JSON fields and the page layout in exact numbers, for the Swift app. |
| `songs/UNCERTAIN.md` | Every line or chord that still needs Marko's ear or a native speaker. |
| `songs/evidence/*.analysis.json` | Audio-analysis numbers per song (tempo, key, chord path, basic-pitch pitch classes). |
| `tools/cho2json.py` | `.cho` -> `.json`. |
| `tools/render_pdf.py` | `.json` -> `PDFs/<nn> <Title>.pdf` (PyMuPDF, Open Sans). `--png DIR` writes previews. |
| `tools/notation.py` | Vector notation: the MELODY staff (page 1) and the frame-drum RHYTHM box (page 2), MPA Academy conventions. |
| `tools/analysis/rhythm_check.py`, `melody_plot.py` | Meter from the drums stem (Dum gaps, autocorrelation); pitch picture of a sung phrase. |
| `tools/check_lyrics.py` | Every JSON lyric line must be word for word in `source/Pjesme tekstovi.pdf`. |
| `tools/analysis/` | `analyze.py`, `restricted.py`, `windows.py`: chord/structure analysis of the Demucs stems. |
| `PDFs/` | The five finished PDFs (also copied to `~/Documents/ETHNO-HRVATSKA/PDF/`). |
| `source/` | `Pjesme tekstovi.pdf` (authoritative words, 21.11.2026), the Wein aa Ramallah INFO sheet, `images/` = flipchart photos (downscaled; the Preli prelo lyric photos are cropped to the sheet so no face is shown). |
| `fonts/` | Open Sans Regular/Italic/Semibold/Bold (Apache 2.0). |
| `skill/ETHNO-PDF-SKILL.md` | The skill; also installed as `~/.claude/skills/ethno-song-pdf/SKILL.md`. |

Run: `python3 tools/cho2json.py && python3 tools/check_lyrics.py && python3 tools/render_pdf.py --png /tmp/ethno`.

## Not in the repo (too big, stay in ~/Documents/ETHNO-HRVATSKA)

- `01 Wein aa Ramallah Etno orkestar arr 30-09-26.m4a` (3.1 MB, 3:11)
- `02 Preli prelo Etno orkestar arr 30-09-26.m4a` (3.4 MB, 3:33)
- `03 Da bi naši starci znali Etno orkestar 21-10.m4a` (4.6 MB, 4:34)
- `04Dremle mi se Etno orkestar 21-10.m4a` (8.7 MB, 8:56)
- `05 Rosaura Lindaura.m4a` (4.6 MB, 4:43)
- the original HEIC photos, the earlier transcripts (`*.transcript.*`, `*.resolve.transcript.*`, useless for the sung parts),
  `PDF/.work/` (stems and MIDI of 19.11.2026), and the old PDFs in `PDF/old/`.
- Stems of 21.11.2026 (Demucs for songs 1, 2, 4; Resolve Voice Isolation for songs 1, 2, 4) were made in a scratch folder and not kept;
  re-make them with the commands in the skill if needed.

## State on 21.11.2026

| Song | Key | Chords (main) | Confidence |
|---|---|---|---|
| 01 Wein aa Ramallah | D minor, Maqam Bayati on D | Dm, Gm, A7 (audio only, no chord board) | low-medium |
| 02 Preli prelo | E minor | Em, Am, B (H), D | medium |
| 03 Da bi naši starci znali | G minor | Gm, Cm, Bb, D, F; V1-V2 Gm drone only | medium |
| 04 Dremle mi se | D minor (Dorian) | Dm-G, C->Am, F; solo Dm G Dm G Dm G Bb C | medium-high |
| 05 Rosaura Lindaura | A minor | intro G7 C E7 Am; Am, C, Em7, F, G, E7 | high (intro, A), medium (B, C) |

## Melody and rhythm (21.11.2026, evening)

Marko: "From the PDF remove my notes on rhythm. Make official rhythm notes any percussionist can understand ... Everything on how to
write rhythms is in MPA Academy", then "frame drum", then "I need a staff at the top. There is a melody line and lyrics."
Done: his shorthand is gone from every sheet; each song has a `rhythm` object (MPA cells, two-line frame-drum staff, confidence) and
a `melody` object (staff at the top of page 1). Per song, with confidence, in `songs/UNCERTAIN.md` (section "Melody and rhythm"):
Malfouf 2/4 (songs 1, 2, confirmed), Aksak 5/8 2+3 (song 3, five per bar confirmed, order to confirm), 3/4 (song 4, confirmed;
strokes to confirm), Huayno 2/4 (song 5, figure confirmed; strokes to confirm). Melodies: drafts for 1, 2, 4; songs 3 and 5 have an
empty staff (voice not separable on the recording). Layout numbers for the Swift app: `songs/SCHEMA.md` sections 5 and 6.
Stems of this evening (Demucs, songs 1, 2, 4) were made in a scratch folder and not kept.

## Next

- A Swift Mac app in this repo re-implementing `render_pdf.py` from `songs/SCHEMA.md` (next worker). Compile only via GitHub
  Actions (copy the Mac Swift workflow from MANTRA_MANIFEST/workflows/ as the first commit of the app), updater at start.
- Marko's ear on `songs/UNCERTAIN.md`; each answer goes into the `.cho`, then regenerate.
- The professor (Marko) confirms the rhythm strokes of songs 3-5 and the melody drafts of 1, 2, 4; the melodies of 3 and 5 come
  from him (sung or written) or a cleaner recording.
- Swift app v2: implement `melody` and the `rhythm` box from SCHEMA.md 5-6 (another worker).

## The Mac app (21.11.2026, v1)

`app/*.swift` + `build.sh` + `.github/workflows/build.yml`. Never compile on the Mac: push to main, the run builds and marks release vN Latest; install with `gh release download` + `ditto` + `codesign -s "Mantra Apps"`. Version is `let VERSION = N` in app/App.swift. Library default ~/Documents/ETHNO-HRVATSKA (macOS asks for Documents access on first run; the app shows an amber PERMISSIONS button if refused). Open: rhythm object and melody staff once SCHEMA.md documents them (v2); an icon; the Analyse button is untested here (needs librosa, pretty_midi, demucs).
