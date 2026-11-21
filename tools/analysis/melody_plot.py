"""Pitch picture of a sung phrase, for transcribing the melody by eye (21.11.2026).
usage: python3 melody_plot.py <vocals.wav> <drums.wav> <start_s> <end_s> <tuning_cents> <out.png>
pYIN f0 of the vocal stem (black dots, note names on the y axis after removing the tuning offset), drum onsets
(red = Dum, grey = other strokes) and vocal onsets (green ticks at the bottom). Read the syllables off the picture,
quantise them to the meter found with rhythm_check.py and write them as {melody:} tokens in the .cho.
"""
import sys, numpy as np, librosa, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

vocal, drums, a, b, off, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]), sys.argv[6]
yv, sv = librosa.load(vocal, sr=16000, offset=a, duration=b - a)
f0, _, vp = librosa.pyin(yv, fmin=65, fmax=1000, sr=sv, frame_length=1024, hop_length=160)
t = a + np.arange(len(f0)) * 160 / sv
m = librosa.hz_to_midi(f0) - off / 100
m[vp < 0.3] = np.nan
fig, ax = plt.subplots(figsize=(22, 6), dpi=80)
y, sr = librosa.load(drums, sr=22050, offset=a, duration=b - a)
hop = 128
S = np.abs(librosa.stft(y, n_fft=1024, hop_length=hop))
f = librosa.fft_frequencies(sr=sr, n_fft=1024)
env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
lo, hi = S[f < 200].sum(0), S[f > 2000].sum(0)
for fr in librosa.onset.onset_detect(onset_envelope=env, sr=sr, hop_length=hop, delta=0.07):
    dum = lo[fr:fr + 6].sum() / (hi[fr:fr + 6].sum() + 1e-9) > 2
    ax.axvline(a + fr * hop / sr, color='red' if dum else '#bbb', lw=1.6 if dum else 0.6)
ev = librosa.onset.onset_strength(y=yv, sr=sv, hop_length=160)
for fr in librosa.onset.onset_detect(onset_envelope=ev, sr=sv, hop_length=160, delta=0.08, wait=8):
    ax.axvline(a + fr * 160 / sv, ymax=0.08, color='green', lw=2)
ax.plot(t, m, '.', ms=3, color='k')
lo_, hi_ = int(np.nanpercentile(m, 2) - 2), int(np.nanpercentile(m, 98) + 2)
ax.set_ylim(lo_, hi_)
ax.set_yticks(range(lo_, hi_ + 1))
ax.set_yticklabels([librosa.midi_to_note(v) for v in range(lo_, hi_ + 1)])
ax.grid(axis='y', color='#ddd')
ax.set_xticks(np.arange(np.ceil(a), b, 0.5))
ax.set_xlim(a, b)
plt.tight_layout()
plt.savefig(out)
