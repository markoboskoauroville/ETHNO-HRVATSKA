"""Chord/structure analysis for one song.
usage: python3 analyze.py <mix.m4a> <stemdir with other.wav bass.wav vocals.wav> <out.json> [midi_other.mid]
Harmony = CQT chroma of (other + bass) stems, optionally fused with basic-pitch MIDI
pitch-class weights; beat-synchronous; template match + Viterbi smoothing.
"""
import sys, json, numpy as np, librosa, pretty_midi

mix, stemdir, out = sys.argv[1], sys.argv[2], sys.argv[3]
midi = sys.argv[4] if len(sys.argv) > 4 else None
SR = 22050
NOTES = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']

y, _ = librosa.load(mix, sr=SR, mono=True)
o, _ = librosa.load(f"{stemdir}/other.wav", sr=SR, mono=True)
b, _ = librosa.load(f"{stemdir}/bass.wav", sr=SR, mono=True)
v, _ = librosa.load(f"{stemdir}/vocals.wav", sr=SR, mono=True)
d, _ = librosa.load(f"{stemdir}/drums.wav", sr=SR, mono=True)
n = min(len(y), len(o), len(b), len(v))
y, o, b, v, d = y[:n], o[:n], b[:n], v[:n], d[:n]

# tempo/beats from drums+mix onset
onset = librosa.onset.onset_strength(y=d + 0.5 * y, sr=SR)
tempo, beats = librosa.beat.beat_track(onset_envelope=onset, sr=SR, units='frames')
beat_t = librosa.frames_to_time(beats, sr=SR)
tempo = float(np.atleast_1d(tempo)[0])

harm = librosa.effects.harmonic(o + 1.2 * b)
hop = 512
chroma = librosa.feature.chroma_cqt(y=harm, sr=SR, hop_length=hop, bins_per_octave=36)
bass_chroma = librosa.feature.chroma_cqt(y=librosa.effects.harmonic(b), sr=SR, hop_length=hop, fmin=librosa.note_to_hz('E1'), n_octaves=3)
sync = librosa.util.sync(chroma, beats, aggregate=np.median)
bsync = librosa.util.sync(bass_chroma, beats, aggregate=np.median)
nb = sync.shape[1]
edges = np.concatenate([[0.0], beat_t, [n / SR]])[: nb + 1]

if midi:
    pm = pretty_midi.PrettyMIDI(midi)
    mpc = np.zeros((12, nb))
    for inst in pm.instruments:
        for note in inst.notes:
            for k in range(nb):
                s, e = edges[k], edges[k + 1]
                ov = min(e, note.end) - max(s, note.start)
                if ov > 0:
                    mpc[note.pitch % 12, k] += ov * note.velocity / 127.0
    mpc = mpc / (mpc.max(axis=0, keepdims=True) + 1e-9)
    sync = 0.6 * (sync / (sync.max(axis=0, keepdims=True) + 1e-9)) + 0.4 * mpc

# templates
labels, T = [], []
def add(name, root, ivs, w=1.0):
    t = np.zeros(12)
    for i, iv in enumerate(ivs):
        t[(root + iv) % 12] = 1.0 if i < 3 else 0.6
    labels.append(name); T.append(w * t / np.linalg.norm(t))
for r in range(12):
    add(NOTES[r], r, [0, 4, 7])
    add(NOTES[r] + 'm', r, [0, 3, 7])
    add(NOTES[r] + '7', r, [0, 4, 7, 10], 0.97)
    add(NOTES[r] + 'm7', r, [0, 3, 7, 10], 0.95)
T = np.array(T)
X = sync / (np.linalg.norm(sync, axis=0, keepdims=True) + 1e-9)
S = T @ X  # (labels, beats)
# bass root bonus
def root_of(l):
    for nm in sorted(NOTES, key=len, reverse=True):
        if l.startswith(nm):
            return NOTES.index(nm)
roots = np.array([root_of(l) for l in labels])
bn = bsync / (bsync.max(axis=0, keepdims=True) + 1e-9)
S = S + 0.25 * bn[roots, :]
# energy mask -> N
rms = librosa.util.sync(librosa.feature.rms(y=o + b, hop_length=hop), beats, aggregate=np.mean)[0]
# viterbi
P = np.exp(8 * S)
P = P / P.sum(axis=0, keepdims=True)
L = len(labels)
stay = 0.9
trans = np.full((L, L), (1 - stay) / (L - 1)); np.fill_diagonal(trans, stay)
path = librosa.sequence.viterbi(P, trans)
seq = [labels[i] for i in path]

# segments
segs = []
for k, c in enumerate(seq):
    if segs and segs[-1]['chord'] == c:
        segs[-1]['beats'] += 1; segs[-1]['end'] = float(edges[k + 1])
    else:
        segs.append({'chord': c, 'start': float(edges[k]), 'end': float(edges[k + 1]), 'beats': 1})

# key estimate from whole-song chroma (Krumhansl)
maj = np.array([6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88])
mnr = np.array([6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17])
tot = chroma.sum(axis=1)
keys = []
for r in range(12):
    keys.append((np.corrcoef(tot, np.roll(maj, r))[0, 1], NOTES[r] + ' major'))
    keys.append((np.corrcoef(tot, np.roll(mnr, r))[0, 1], NOTES[r] + ' minor'))
keys.sort(reverse=True)

# vocal activity windows (where singing happens)
vr = librosa.feature.rms(y=v, hop_length=hop)[0]
vt = librosa.frames_to_time(np.arange(len(vr)), sr=SR, hop_length=hop)
thr = max(0.02, np.percentile(vr, 60) * 0.6)
act, cur = [], None
for t, val in zip(vt, vr):
    if val > thr and cur is None: cur = t
    if val <= thr and cur is not None:
        if t - cur > 0.4: act.append([round(float(cur), 2), round(float(t), 2)])
        cur = None
merged = []
for a in act:
    if merged and a[0] - merged[-1][1] < 1.2: merged[-1][1] = a[1]
    else: merged.append(a)

hist = {}
for s in segs: hist[s['chord']] = hist.get(s['chord'], 0) + s['beats']
json.dump({'tempo_bpm': round(tempo, 1), 'n_beats': nb, 'key_candidates': [[round(float(c), 3), k] for c, k in keys[:4]],
           'chord_beats_histogram': dict(sorted(hist.items(), key=lambda x: -x[1])),
           'pitch_class_profile': {NOTES[i]: round(float(tot[i] / tot.max()), 3) for i in range(12)},
           'vocal_phrases': merged, 'segments': segs}, open(out, 'w'), indent=1)
print(out, round(tempo, 1), keys[:3], list(hist.items())[:0])
