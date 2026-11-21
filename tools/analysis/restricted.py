"""Restricted-vocabulary chord path over fixed windows, with free best for comparison.
usage: restricted.py <stemdir> <vocalwav> <win> <vocab comma> <out.json> [t0 t1] [--drone]
Writes JSON with per-window: t, restricted chord, its score, free best chord+score, vocal flag,
plus compressed segments and a 'fit' ratio (mean restricted/free score)."""
import sys, json, numpy as np, librosa
a = [x for x in sys.argv[1:] if x != '--drone']
drone = '--drone' in sys.argv
stem, vocal, W, vocab, out = a[0], a[1], float(a[2]), a[3].split(','), a[4]
t0 = float(a[5]) if len(a) > 5 else 0.0
t1 = float(a[6]) if len(a) > 6 else None
SR = 22050; hop = 512; fps = SR / hop
NOTES = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']
ALIAS = {'A#': 'Bb', 'Db': 'C#', 'D#': 'Eb', 'Gb': 'F#', 'G#': 'Ab', 'H': 'B'}
Q = {'': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10]}
def tmpl(name):
    for nm in sorted(list(NOTES) + list(ALIAS), key=len, reverse=True):
        if name.startswith(nm):
            r = NOTES.index(ALIAS.get(nm, nm)); q = name[len(nm):]; break
    t = np.zeros(12)
    for i, iv in enumerate(Q[q]): t[(r + iv) % 12] = 1 if i < 3 else .55
    return t / np.linalg.norm(t), r
dur = None if t1 is None else t1 - t0
ld = lambda f: librosa.load(f, sr=SR, mono=True, offset=t0, duration=dur)[0]
o, b = ld(f"{stem}/other.wav"), ld(f"{stem}/bass.wav")
v = ld(vocal)
c = librosa.feature.chroma_cqt(y=librosa.effects.harmonic(o + b), sr=SR, hop_length=hop, bins_per_octave=36)
cb = librosa.feature.chroma_cqt(y=b, sr=SR, hop_length=hop, fmin=librosa.note_to_hz('E1'), n_octaves=3)
if drone:
    c = np.maximum(c - 0.7 * np.median(c, axis=1, keepdims=True), 0)
full = [n + q for n in NOTES for q in Q]
FT = np.array([tmpl(x)[0] for x in full]); FR = np.array([tmpl(x)[1] for x in full])
VT = np.array([tmpl(x)[0] for x in vocab]); VR = np.array([tmpl(x)[1] for x in vocab])
vr = librosa.feature.rms(y=v, hop_length=hop)[0]
vthr = max(0.01, np.percentile(vr, 70) * 0.5)
n = int(c.shape[1] / fps / W)
X, B, voc = [], [], []
for k in range(n):
    s, e = int(k * W * fps), int((k + 1) * W * fps)
    x = c[:, s:e].mean(axis=1); X.append(x / (np.linalg.norm(x) + 1e-9))
    bb = cb[:, s:e].mean(axis=1); B.append(bb / (bb.max() + 1e-9))
    voc.append(bool(vr[s:min(e, len(vr))].mean() > vthr))
X, B = np.array(X).T, np.array(B).T
SV = VT @ X + 0.15 * B[VR, :]
SF = FT @ X + 0.15 * B[FR, :]
P = np.exp(40 * SV); P /= P.sum(axis=0, keepdims=True)
L = len(vocab); stay = 0.5
tr = np.full((L, L), (1 - stay) / max(1, L - 1)); np.fill_diagonal(tr, stay)
path = librosa.sequence.viterbi(P, tr) if L > 1 else np.zeros(n, int)
rows, segs = [], []
for k in range(n):
    ch = vocab[path[k]]; fb = int(np.argmax(SF[:, k]))
    rows.append({'t': round(t0 + k * W, 2), 'chord': ch, 'score': round(float(SV[path[k], k]), 3),
                 'free': full[fb], 'free_score': round(float(SF[fb, k]), 3), 'vocal': voc[k]})
    if segs and segs[-1]['chord'] == ch: segs[-1]['n'] += 1
    else: segs.append({'t': round(t0 + k * W, 2), 'chord': ch, 'n': 1, 'vocal': voc[k]})
fit = float(np.mean([r['score'] / r['free_score'] for r in rows]))
json.dump({'window_s': W, 'vocab': vocab, 'fit': round(fit, 3), 'segments': segs, 'windows': rows}, open(out, 'w'), indent=0)
print(f"fit={fit:.3f}")
line = []
for sg in segs:
    line.append(f"{sg['t']:.1f}{'*' if sg['vocal'] else ''} {sg['chord']}x{sg['n']}")
for i in range(0, len(line), 10): print(' | '.join(line[i:i + 10]))
