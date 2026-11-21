# Lessons

- 21.11.2026: Whisper (the :8837 voice API, also with lang=es and word times) cannot transcribe sung rehearsal takes, even from
  Resolve-isolated vocals: it returns "thanks for watching" / Japanese "iya iya" hallucinations. Lyrics come from the sheet, not audio.
- 21.11.2026: Chroma chord detection on phone rehearsal takes is noisy; a free 48-chord search is close to useless. What works:
  restrict the search to the chords on the flipchart (plus a few neighbours), 2-beat windows, light Viterbi smoothing, and read the
  free best chord beside it as a check. On drone songs subtract the median chroma first (`--drone`).
- 21.11.2026: The beat tracker gives one number per song; for 2+3 (aksak) and malfouf feels the BPM is approximate. Say so.
- 21.11.2026: DaVinci Resolve 21 scripting: WAV is not a render format (GetRenderCodecs('wav') is empty). Render MOV with
  ExportVideo False + AudioCodec lpcm and convert with ffmpeg. Voice Isolation is scriptable per track
  (`Timeline.SetVoiceIsolationState`); Music Remixer stems are not.
- 21.11.2026: PIL ignores EXIF orientation: use `ImageOps.exif_transpose` before cropping phone photos.
- 21.11.2026: PyMuPDF orphans earlier Page objects when a new page is added: finish (footer included) each page before `new_page`.
- 21.11.2026: The 19.11.2026 PDF of Dremle mi se carried the words of a different song; always check sheet words against the source
  (`tools/check_lyrics.py`).
- 21.11.2026: Croatian chord names on the boards: H = B, B = Bb, A# written for Bb, lowercase e / a = Em / Am. On the Rosaura board the
  chords are written under the syllable.
- 21.11.2026: Phone photos carry GPS in EXIF; every image is re-saved without EXIF (after exif_transpose) before it goes into a public repo.
- 21.11.2026: Swift app: a closure in applicationDidFinishLaunching needs `self.` for method calls; the GitHub run is the only compiler check, so one error per push is normal.
- 21.11.2026: The librosa beat tracker's BPM was a sub-pulse in all five songs (Wein 129 = the dotted-8th of Malfouf, real ♩ ≈ 95;
  Preli 117, real ♩ ≈ 61-73; Rosaura 112, real ♩ ≈ 85). Measure the bar: autocorrelation of the drums-stem onsets plus the gaps
  between Dum strokes (energy < 200 Hz over > 2 kHz) counted in pulses (`tools/analysis/rhythm_check.py`).
- 21.11.2026: Beat-synchronous folding of the accent pattern fails when the tracker skips pulses; the Dum-gap histogram is robust
  (Da bi naši: 66 gaps of 3, 61 of 2 = 5/8).
- 21.11.2026: Vocal pitch on phone rehearsal takes: pYIN on the Demucs vocal stem works for a solo voice (Preli prelo V1, Dremle A),
  not for a voice under a drone or a quiet choir (Da bi naši, Rosaura: basic-pitch and the Resolve stem gave fragments only). Plot the
  f0 with the drum and vocal onsets and transcribe by eye; say "draft" and never fill gaps by invention.
- 21.11.2026: Open Sans has no ♩ ♪; music glyphs (G clef U+1D11E, ♭ ♯ ♮, ♩ ♪) come from the macOS font Apple Symbols, which has no
  rest or notehead glyphs: heads, stems, beams, rests and the half-flat slash are drawn as vectors. Apple Symbols' ♭ baseline sits
  0.45 staff space below the note, ♯ and ♮ 1.05.
- 21.11.2026: MPA spoons make Marko's count readable for everyone: Aksak 5/8 as D - D - - has spoons 1 2 1 2 3 = his "12|123".
- 21.11.2026: Marko wants no page tags (FOR SINGERS / FOR GUITAR) and no footers: everything needed is already on the page.
