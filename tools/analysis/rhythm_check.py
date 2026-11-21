"""Meter check for one song from its Demucs drums stem (21.11.2026).
usage: python3 rhythm_check.py <drums.wav> <start_s> <dur_s> <pulse_s> [low/high threshold, default 3]
Prints (1) onset-envelope autocorrelation peaks (bar and group lengths) and (2) the gaps between Dum strokes
(onsets whose energy below 200 Hz dominates above 2 kHz) counted in pulses. A Malfouf shows 3 3 2, a 2+3 aksak
alternating 2 3, a 3/4 groove multiples of 3. The pulse is the fastest even grid (a 16th for Malfouf, an 8th for 5/8).
"""
import sys, collections, numpy as np, librosa

path, t0, dur, pulse = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
thr = float(sys.argv[5]) if len(sys.argv) > 5 else 3.0
y, sr = librosa.load(path, sr=22050, offset=t0, duration=dur, mono=True)
hop = 128
fps = sr / hop
env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
e = env - env.mean()
ac = np.correlate(e, e, 'full')[len(e) - 1:]
ac /= ac[0]
lags = np.arange(int(0.08 * fps), int(3.2 * fps))
peaks = [l for l in lags[1:-1] if ac[l] > ac[l - 1] and ac[l] > ac[l + 1] and ac[l] > 0.05]
print('autocorrelation peaks (lag s, in pulses, strength):')
for l in sorted(sorted(peaks, key=lambda l: -ac[l])[:12]):
    print(f'  {l / fps:6.3f}s  {l / fps / pulse:5.2f}  {ac[l]:.3f}')
on = librosa.onset.onset_detect(onset_envelope=env, sr=sr, hop_length=hop, delta=0.07)
S = np.abs(librosa.stft(y, n_fft=1024, hop_length=hop))
f = librosa.fft_frequencies(sr=sr, n_fft=1024)
lo, hi = S[f < 200].sum(0), S[f > 2000].sum(0)
t = librosa.frames_to_time(on, sr=sr, hop_length=hop)
d = [tt for fr, tt in zip(on, t) if lo[fr:fr + 6].sum() / (hi[fr:fr + 6].sum() + 1e-9) > thr]
g = [round((b - a) / pulse) for a, b in zip(d[:-1], d[1:])]
print(f'dum strokes: {len(d)}; gaps in pulses:')
print(' '.join(map(str, g)))
print('most common gaps:', collections.Counter(g).most_common(6))
