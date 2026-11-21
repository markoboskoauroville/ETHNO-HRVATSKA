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
