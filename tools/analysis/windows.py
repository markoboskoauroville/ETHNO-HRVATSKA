"""Fixed-window chord candidates. usage: windows.py <stemdir> <win_sec> <t0> <t1> [drone]
Prints per window: time, top-3 chords (score), strongest bass pitch class, vocal on/off."""
import sys, numpy as np, librosa
stem, W, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
drone = len(sys.argv) > 5
SR = 22050
NOTES = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']
dur = t1 - t0
ld = lambda f: librosa.load(f"{stem}/{f}.wav", sr=SR, mono=True, offset=t0, duration=dur)[0]
o, b, v = ld('other'), ld('bass'), ld('vocals')
hop = 512
c = librosa.feature.chroma_cqt(y=librosa.effects.harmonic(o + b), sr=SR, hop_length=hop, bins_per_octave=36)
cb = librosa.feature.chroma_cqt(y=b, sr=SR, hop_length=hop, fmin=librosa.note_to_hz('E1'), n_octaves=3)
cv = librosa.feature.chroma_cqt(y=v, sr=SR, hop_length=hop)
if drone:
    c = np.maximum(c - 0.8 * np.median(c, axis=1, keepdims=True), 0)
fps = SR / hop
labels, T = [], []
for r in range(12):
    for suf, ivs in (('', [0, 4, 7]), ('m', [0, 3, 7]), ('7', [0, 4, 7, 10])):
        t = np.zeros(12)
        for i, iv in enumerate(ivs): t[(r + iv) % 12] = 1 if i < 3 else .5
        labels.append(NOTES[r] + suf); T.append(t / np.linalg.norm(t))
T = np.array(T)
vr = librosa.feature.rms(y=v, hop_length=hop)[0]
n = int(dur / W)
for k in range(n):
    a, z = int(k * W * fps), int((k + 1) * W * fps)
    x = c[:, a:z].mean(axis=1); x = x / (np.linalg.norm(x) + 1e-9)
    s = T @ x
    top = np.argsort(-s)[:3]
    bp = NOTES[int(np.argmax(cb[:, a:z].mean(axis=1)))]
    vm = NOTES[int(np.argmax(cv[:, a:z].mean(axis=1)))]
    voc = 'V' if vr[a:z].mean() > 0.02 else ' '
    print(f"{t0 + k * W:6.1f} {voc} bass={bp:3s} vmel={vm:3s} " + '  '.join(f"{labels[i]:4s}{s[i]:.2f}" for i in top))
