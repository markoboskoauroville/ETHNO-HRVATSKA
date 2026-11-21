import AppKit
import CoreGraphics

// Port of tools/notation.py (songs/SCHEMA.md sections 5 and 6): the MELODY staff and the frame-drum RHYTHM box.
// Paths in a y-down context, glyphs (G clef, flats, sharps) from Apple Symbols.

// ---------------------------------------------------------------- data
struct MNote: Codable, Equatable, Identifiable {
    var id = UUID()
    var pitch: String = "E4"
    var len: Int = 4
    var syllable: String = ""
    var chord: String? = nil
    var tie: Bool = false
    enum CodingKeys: String, CodingKey { case pitch, len, syllable, chord, tie }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        pitch = (try? c.decodeIfPresent(String.self, forKey: .pitch)) ?? "R"
        len = (try? c.decodeIfPresent(Int.self, forKey: .len)) ?? 4
        syllable = ((try? c.decodeIfPresent(String.self, forKey: .syllable)) ?? nil) ?? ""
        chord = (try? c.decodeIfPresent(String.self, forKey: .chord)) ?? nil
        tie = ((try? c.decodeIfPresent(Bool.self, forKey: .tie)) ?? nil) ?? false
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(pitch, forKey: .pitch); try c.encode(len, forKey: .len); try c.encode(syllable, forKey: .syllable)
        try c.encodeIfPresent(chord, forKey: .chord)
        if tie { try c.encode(true, forKey: .tie) }
    }
}

struct KeySig: Codable, Equatable {
    var fifths: Int = 0
    var half_flats: [String] = []
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        fifths = ((try? c.decodeIfPresent(Int.self, forKey: .fifths)) ?? nil) ?? 0
        half_flats = ((try? c.decodeIfPresent([String].self, forKey: .half_flats)) ?? nil) ?? []
    }
    enum CodingKeys: String, CodingKey { case fifths, half_flats }
}

struct Melody: Codable, Equatable {
    var status = "draft"
    var label = ""
    var section: JSONValue? = nil
    var lines: JSONValue? = nil
    var clef = "treble"
    var key_signature = KeySig()
    var time = "4/4"
    var grouping: String? = nil
    var tempo: JSONValue? = nil
    var confidence: JSONValue? = nil
    var source: JSONValue? = nil
    var systems: [[MNote]] = []
    init() {}
    enum CodingKeys: String, CodingKey { case status, label, section, lines, clef, key_signature, time, grouping, tempo, confidence, source, systems }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func opt<T: Decodable>(_ k: CodingKeys) -> T? { ((try? c.decodeIfPresent(T.self, forKey: k)) ?? nil) }
        status = opt(.status) ?? "draft"; label = opt(.label) ?? ""
        section = opt(.section); lines = opt(.lines)
        clef = opt(.clef) ?? "treble"; key_signature = opt(.key_signature) ?? KeySig()
        time = opt(.time) ?? "4/4"; grouping = opt(.grouping)
        tempo = opt(.tempo); confidence = opt(.confidence); source = opt(.source)
        systems = opt(.systems) ?? []
    }
}

struct Rhythm: Codable, Equatable {
    var name = ""
    var instrument: String? = nil
    var meter = "4/4"
    var grouping = ""
    var cell = 16
    var tempo = ""
    var cells: [String] = []
    var syllables: [String] = []
    var events: JSONValue? = nil
    var mpa: JSONValue? = nil
    var practice = ""
    var confidence = ""
    var evidence: JSONValue? = nil
    init() {}
    enum CodingKeys: String, CodingKey { case name, instrument, meter, grouping, cell, tempo, cells, syllables, events, mpa, practice, confidence, evidence }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func opt<T: Decodable>(_ k: CodingKeys) -> T? { ((try? c.decodeIfPresent(T.self, forKey: k)) ?? nil) }
        name = opt(.name) ?? ""; instrument = opt(.instrument); meter = opt(.meter) ?? "4/4"
        grouping = opt(.grouping) ?? ""; cell = opt(.cell) ?? 16; tempo = opt(.tempo) ?? ""
        cells = opt(.cells) ?? []; syllables = opt(.syllables) ?? []
        events = opt(.events); mpa = opt(.mpa); practice = opt(.practice) ?? ""
        confidence = opt(.confidence) ?? ""; evidence = opt(.evidence)
    }
}

// ---------------------------------------------------------------- drawing helpers
enum N {
    static func g(_ v: CGFloat) -> CGColor { CGColor(gray: v, alpha: 1) }
    static let ink = L.hex("#111111"), grey = L.hex("#666666"), light = L.hex("#A0A0A0"), chord = L.hex("#B03A2E")
    static let white = CGColor(gray: 1, alpha: 1)
    static let letters = Array("CDEFGAB")
    static let sharpOrder = Array("FCGDAEB"), flatOrder = Array("BEADGCF")
    static let sharpPos: [Character: Int] = ["F": 8, "C": 5, "G": 9, "D": 6, "A": 3, "E": 7, "B": 4]
    static let flatPos: [Character: Int] = ["B": 4, "E": 7, "A": 3, "D": 6, "G": 2, "C": 5, "F": 1]
    static let gClef = "\u{1D11E}", flat = "\u{266D}", sharp = "\u{266F}", natural = "\u{266E}"
    static let spMelody: CGFloat = 5.6

    /// "E4", "F#4", "Bb3", "Ed4" (half-flat), "Bn4" -> (letter, acc, octave)
    static func parsePitch(_ p: String) -> (Character, String, Int) {
        var chars = Array(p)
        let letter = Character(String(chars.removeFirst()).uppercased())
        var acc = ""
        if let f = chars.first, "#bdn".contains(f) { acc = String(f); chars.removeFirst() }
        return (letter, acc, Int(String(chars)) ?? 4)
    }

    static func keyAcc(_ ks: KeySig) -> [Character: String] {
        var out: [Character: String] = [:]
        let n = ks.fifths
        for l in (n > 0 ? Array(sharpOrder.prefix(n)) : Array(flatOrder.prefix(-n))) { out[l] = n > 0 ? "#" : "b" }
        for l in ks.half_flats { if let c = l.first { out[c] = "d" } }
        return out
    }

    static func staffPos(_ letter: Character, _ octave: Int, _ clef: String) -> Int {
        let o = clef == "treble8" ? octave + 1 : octave
        return o * 7 + (letters.firstIndex(of: letter) ?? 0) - (4 * 7 + 2)
    }

    static func barLen(_ time: String) -> Int {
        let p = time.split(separator: "/").compactMap { Int($0) }
        guard p.count == 2, p[1] > 0 else { return 16 }
        return p[0] * 16 / p[1]
    }

    static func beatGroups(_ time: String, _ grouping: String?) -> [Int] {
        let p = time.split(separator: "/").compactMap { Int($0) }
        guard p.count == 2 else { return [4] }
        let n = p[0], d = p[1]
        if d == 8 {
            let parts: [Int]
            if let g = grouping, !g.isEmpty { parts = g.split(separator: "+").compactMap { Int($0) } }
            else { parts = Array(repeating: 2, count: n / 2) + (n % 2 != 0 ? [n % 2] : []) }
            return parts.map { $0 * 2 }
        }
        return Array(repeating: 16 / max(d, 1), count: n)
    }
}

extension Pg {
    func line(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat = 0.6, _ c: CGColor = N.ink) {
        ctx.saveGState(); ctx.setStrokeColor(c); ctx.setLineWidth(w)
        ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath(); ctx.restoreGState()
    }
    func fillRect(_ r: CGRect, _ c: CGColor = N.ink) { ctx.saveGState(); ctx.setFillColor(c); ctx.fill(r); ctx.restoreGState() }
    func strokeRect(_ r: CGRect, _ w: CGFloat, _ c: CGColor = N.ink) {
        ctx.saveGState(); ctx.setStrokeColor(c); ctx.setLineWidth(w); ctx.stroke(r); ctx.restoreGState()
    }
    func dot(_ c: CGPoint, _ r: CGFloat, _ col: CGColor = N.ink) {
        ctx.saveGState(); ctx.setFillColor(col); ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)); ctx.restoreGState()
    }
    func bezier(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p3: CGPoint, _ w: CGFloat, _ col: CGColor = N.ink) {
        ctx.saveGState(); ctx.setStrokeColor(col); ctx.setLineWidth(w)
        ctx.move(to: p0); ctx.addCurve(to: p3, control1: c1, control2: c2); ctx.strokePath(); ctx.restoreGState()
    }
    func polyline(_ pts: [CGPoint], _ w: CGFloat, _ col: CGColor = N.ink) {
        guard let f = pts.first else { return }
        ctx.saveGState(); ctx.setStrokeColor(col); ctx.setLineWidth(w); ctx.move(to: f)
        for p in pts.dropFirst() { ctx.addLine(to: p) }
        ctx.strokePath(); ctx.restoreGState()
    }
    func head(_ cx: CGFloat, _ cy: CGFloat, _ sp: CGFloat, filled: Bool = true, scale: CGFloat = 1) {
        let w = 1.30 * sp * scale / 2, h = 0.92 * sp * scale / 2
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy); ctx.rotate(by: -20 * .pi / 180)
        let r = CGRect(x: -w, y: -h, width: 2 * w, height: 2 * h)
        ctx.setStrokeColor(N.ink)
        if filled { ctx.setFillColor(N.ink); ctx.setLineWidth(0.1) }
        else { ctx.setFillColor(N.white); ctx.setLineWidth(0.16 * sp * 1.3) }
        ctx.addEllipse(in: r); ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
    }
    func xhead(_ cx: CGFloat, _ cy: CGFloat, _ sp: CGFloat) {
        let d = 0.5 * sp
        line(CGPoint(x: cx - d, y: cy - d), CGPoint(x: cx + d, y: cy + d), 0.9)
        line(CGPoint(x: cx - d, y: cy + d), CGPoint(x: cx + d, y: cy - d), 0.9)
    }
    func glyph(_ x: CGFloat, _ y: CGFloat, _ ch: String, _ size: CGFloat, _ color: CGColor = N.ink) { text(x, y, ch, .sym, size, color) }

    func halfFlat(_ x: CGFloat, _ y: CGFloat, _ sp: CGFloat) {
        glyph(x, y + 0.45 * sp, N.flat, 3.4 * sp)
        line(CGPoint(x: x - 0.15 * sp, y: y - 1.05 * sp), CGPoint(x: x + 1.05 * sp, y: y - 1.75 * sp), 0.7)
    }
    func accidental(_ x: CGFloat, _ y: CGFloat, _ acc: String, _ sp: CGFloat) {
        if acc == "d" { halfFlat(x, y, sp); return }
        let ch = acc == "b" ? N.flat : (acc == "#" ? N.sharp : N.natural)
        let dy: CGFloat = (acc == "b" ? 0.45 : 1.05) * sp
        glyph(x, y + dy, ch, 3.4 * sp)
    }

    func rest(_ cx: CGFloat, _ top: CGFloat, _ sp: CGFloat, _ length: Int) {
        let mid = top + 2 * sp
        if length >= 8 {
            fillRect(CGRect(x: cx - 0.6 * sp, y: mid - 0.5 * sp, width: 1.2 * sp, height: 0.5 * sp))
        } else if length >= 4 {
            let pts = [(0.2, -1.5), (0.6, -0.9), (-0.1, -0.1), (0.5, 0.6), (-0.3, 0.4), (0.2, 1.3)].map { CGPoint(x: cx + $0.0 * sp, y: mid + $0.1 * sp) }
            polyline(pts, 0.9 * sp / 5.6 * 1.4)
        } else {
            let n = length >= 2 ? 1 : 2
            let x0 = cx + 0.45 * sp, y0 = mid - 0.8 * sp
            line(CGPoint(x: x0, y: y0), CGPoint(x: x0 - 0.75 * sp, y: y0 + (1.5 + CGFloat(n)) * sp * 0.75), 0.75)
            for i in 0..<n {
                let fi = CGFloat(i)
                let yy = y0 + fi * sp * 0.75
                dot(CGPoint(x: x0 - 0.75 * sp - 0.05 * sp + fi * -0.25 * sp, y: yy + 0.05 * sp), 0.32 * sp)
                line(CGPoint(x: x0 - 0.75 * sp + fi * -0.25 * sp, y: yy + 0.2 * sp), CGPoint(x: x0 - fi * 0.25 * sp, y: yy), 0.7)
            }
        }
    }

    func flag(_ sx: CGFloat, _ sy: CGFloat, _ sp: CGFloat, _ up: Bool, _ n: Int) {
        let s: CGFloat = up ? 1 : -1
        for i in 0..<n {
            let y = sy + s * CGFloat(i) * 0.8 * sp
            bezier(CGPoint(x: sx, y: y), CGPoint(x: sx + 0.2 * sp, y: y + s * 1.0 * sp), CGPoint(x: sx + 1.3 * sp, y: y + s * 1.3 * sp),
                   CGPoint(x: sx + 0.9 * sp, y: y + s * 2.5 * sp), 0.9)
        }
    }

    func tie(_ x1: CGFloat, _ x2: CGFloat, _ y: CGFloat, _ sp: CGFloat, _ below: Bool) {
        let s: CGFloat = below ? 1 : -1
        bezier(CGPoint(x: x1, y: y), CGPoint(x: x1 + (x2 - x1) * 0.25, y: y + s * 0.9 * sp),
               CGPoint(x: x1 + (x2 - x1) * 0.75, y: y + s * 0.9 * sp), CGPoint(x: x2, y: y), 0.8)
    }
}

// ---------------------------------------------------------------- melody
final class MElem {
    var isBar = false
    var n: MNote?
    var w: CGFloat = 0
    var acc: String?
    var start16 = 0
    var final = false
    var pos = 0
    var hx: CGFloat = 0
    var hy: CGFloat?
}

enum Notation {
    static func tw(_ s: String, _ f: Face, _ size: CGFloat) -> CGFloat { Renderer.width(s, f, size) }

    static func layoutMelody(_ mel: Melody, _ width: CGFloat, _ k: CGFloat = 1) -> Block {
        let sp = N.spMelody * k
        let systems = mel.systems
        let labelH = 8 * k * 1.9
        var geo: [(h: CGFloat, draw: (Pg, CGFloat, CGFloat) -> Void)] = []
        let list: [[MNote]] = systems.isEmpty ? [[]] : systems
        for (si, notes) in list.enumerated() {
            geo.append(systemGeometry(mel, notes, width, sp, first: si == 0, last: si == systems.count - 1 || systems.isEmpty))
        }
        let h = labelH + geo.reduce(0) { $0 + $1.h } + 6 * k
        return Block(h: h) { p, x, y in
            let lab = "MELODY  ·  \(mel.label)"
            var ls = 8 * k
            if tw(lab, .S, ls) > width { ls = max(ls * 0.62, ls * width / tw(lab, .S, ls)) }
            p.text(x, y + 8 * k, lab, .S, ls, N.light)
            var yy = y + labelH
            for g in geo { g.draw(p, x, yy); yy += g.h }
        }
    }

    static func systemGeometry(_ mel: Melody, _ notes: [MNote], _ width: CGFloat, _ sp: CGFloat, first: Bool, last: Bool) -> (h: CGFloat, draw: (Pg, CGFloat, CGFloat) -> Void) {
        let clef = mel.clef
        let ks = mel.key_signature
        let kacc = N.keyAcc(ks)
        let time = mel.time
        let blen = N.barLen(time)
        let groups = N.beatGroups(time, mel.grouping)
        let fifths = ks.fifths
        let hf = ks.half_flats
        let nsig = abs(fifths) + hf.count
        let prefix = 0.6 * sp + 3.9 * sp + (nsig > 0 ? CGFloat(nsig) * 1.3 * sp + 0.8 * sp : 0.4 * sp) + (first ? (2.6 + 1.0) * sp : 0)
        let lyrSize = 9.5 * sp / N.spMelody
        let chordSize = 9.5 * sp / N.spMelody

        var elems: [MElem] = []
        var acc16 = 0
        for n in notes {
            let e = MElem(); e.n = n
            var shown: String? = nil
            if n.pitch != "R" {
                let (letter, acc, _) = N.parsePitch(n.pitch)
                var want = acc
                let have = kacc[letter] ?? ""
                if want == "n" { want = "" }
                if want != have { shown = want.isEmpty ? "n" : want }
            }
            let sw = n.syllable.isEmpty ? 0 : tw(n.syllable, .R, lyrSize)
            let cw = (n.chord ?? "").isEmpty ? 0 : tw(n.chord!, .B, chordSize)
            let base = (2.2 + 1.5 * (CGFloat(n.len) / 2).squareRoot()) * sp
            e.w = max(base, sw + 0.9 * sp, cw + 0.8 * sp) + (shown != nil ? 1.6 * sp : 0)
            e.acc = shown; e.start16 = acc16
            elems.append(e)
            acc16 += n.len
            if blen > 0 && acc16 % blen == 0 { let b = MElem(); b.isBar = true; b.w = 1.4 * sp; elems.append(b) }
        }
        if let l = elems.last, l.isBar, last { l.final = true }
        let natural = elems.reduce(0) { $0 + $1.w }
        let avail = width - prefix
        var stretch: CGFloat = natural > 0 ? avail / natural : 1
        if notes.isEmpty { stretch = 1 }
        var poss: [Int] = []
        for e in elems where !e.isBar {
            if let n = e.n, n.pitch != "R" {
                let (l, _, o) = N.parsePitch(n.pitch)
                e.pos = N.staffPos(l, o, clef); poss.append(e.pos)
            }
        }
        let hiPos = (poss + [8]).max()!
        let loPos = (poss + [0]).min()!
        let topReach = max(hiPos, (poss.filter { $0 < 4 }.map { $0 + 7 } + [8]).max()!)
        let botReach = min(loPos, (poss.filter { $0 >= 4 }.map { $0 - 7 } + [0]).min()!)
        let above = CGFloat(topReach - 8) * sp / 2 + 1.0 * sp
        let below = CGFloat(0 - botReach) * sp / 2 + 0.8 * sp
        let chordGap = max(above, 1.2 * sp) + chordSize * 0.2
        let staffTopOff = chordSize + chordGap
        let lyrBaseOff = staffTopOff + 4 * sp + max(below, 1.0 * sp) + lyrSize
        let height = lyrBaseOff + lyrSize * 0.9 + 4 * sp / N.spMelody

        return (height, { pg, x, y in
            let top = y + staffTopOff
            let bot = top + 4 * sp
            for i in 0..<5 { pg.line(CGPoint(x: x, y: top + CGFloat(i) * sp), CGPoint(x: x + width, y: top + CGFloat(i) * sp), 0.5) }
            pg.line(CGPoint(x: x, y: top), CGPoint(x: x, y: bot), 0.6)
            let cx = x + 0.6 * sp
            pg.glyph(cx, bot + 1.15 * sp, N.gClef, 7.4 * sp)
            if clef == "treble8" { pg.text(cx + 1.15 * sp, bot + 2.9 * sp, "8", .R, 1.7 * sp, N.ink) }
            var kx = cx + 3.9 * sp
            var signs: [(Character, String)] = (fifths > 0 ? Array(N.sharpOrder.prefix(fifths)) : Array(N.flatOrder.prefix(-fifths))).map { ($0, fifths > 0 ? "#" : "b") }
            signs += hf.compactMap { $0.first }.map { ($0, "d") }
            for (l, a) in signs {
                let p = (a == "#" ? N.sharpPos : N.flatPos)[l] ?? 4
                pg.accidental(kx, bot - CGFloat(p) * sp / 2, a, sp)
                kx += 1.3 * sp
            }
            kx += signs.isEmpty ? 0.4 * sp : 0.8 * sp
            if first {
                let parts = time.split(separator: "/").map(String.init)
                if parts.count == 2 {
                    let ts = 2.75 * sp
                    for (txt, base) in [(parts[0], top + 2 * sp), (parts[1], top + 4 * sp)] {
                        let w = tw(txt, .B, ts)
                        pg.text(kx + 1.3 * sp - w / 2, base - 0.02 * sp, txt, .B, ts, N.ink)
                    }
                }
                kx += (2.6 + 1.0) * sp
            }
            let chordBase = y + chordSize
            let lyrBase = y + lyrBaseOff
            var xx = kx
            var placed: [MElem] = []
            for e in elems {
                let w = e.w * stretch
                if e.isBar {
                    let bx = xx + w / 2
                    if e.final {
                        pg.line(CGPoint(x: bx - 1.2, y: top), CGPoint(x: bx - 1.2, y: bot), 0.6)
                        pg.line(CGPoint(x: x + width - 1.0, y: top), CGPoint(x: x + width - 1.0, y: bot), 2.0)
                    } else { pg.line(CGPoint(x: bx, y: top), CGPoint(x: bx, y: bot), 0.6) }
                    xx += w; continue
                }
                let n = e.n!
                e.hx = xx + (e.acc != nil ? 1.6 * sp : 0) + 0.95 * sp
                placed.append(e)
                if let c = n.chord, !c.isEmpty { pg.text(e.hx - 0.65 * sp, chordBase, c, .B, chordSize, N.chord) }
                xx += w
            }
            if !notes.isEmpty, let l = elems.last, !l.isBar {
                pg.line(CGPoint(x: x + width, y: top), CGPoint(x: x + width, y: bot), 0.6)
            }
            drawNotes(pg, placed, top, bot, sp, groups, blen)
            var prevEnd: CGFloat? = nil
            for e in placed {
                let syl = e.n!.syllable
                if syl.isEmpty { if !e.n!.tie { prevEnd = nil }; continue }
                let txt = syl.hasSuffix("-") ? String(syl.dropLast()) : syl
                let w = tw(txt, .R, lyrSize)
                let sx = e.hx - w / 2
                pg.text(sx, lyrBase, txt, .R, lyrSize, N.ink)
                if let pe = prevEnd {
                    let hw = tw("-", .R, lyrSize)
                    if sx - pe > hw + 1 { pg.text((pe + sx) / 2 - hw / 2, lyrBase, "-", .R, lyrSize, N.ink) }
                }
                prevEnd = syl.hasSuffix("-") ? sx + w : nil
            }
            if notes.isEmpty {
                let span = (x + width - kx) / 4
                for i in 1..<4 { pg.line(CGPoint(x: kx + CGFloat(i) * span, y: top), CGPoint(x: kx + CGFloat(i) * span, y: bot), 0.6) }
                pg.line(CGPoint(x: x + width, y: top), CGPoint(x: x + width, y: bot), 0.6)
            }
        })
    }

    static func drawNotes(_ pg: Pg, _ placed: [MElem], _ top: CGFloat, _ bot: CGFloat, _ sp: CGFloat, _ groups: [Int], _ blen: Int) {
        func ypos(_ p: Int) -> CGFloat { bot - CGFloat(p) * sp / 2 }
        var bounds: [(Int, Int)] = []
        var a = 0
        for g in groups { bounds.append((a, a + g)); a += g }
        func groupOf(_ s16: Int) -> [Int] {
            let s = blen > 0 ? s16 % blen : s16
            for (i, b) in bounds.enumerated() where b.0 <= s && s < b.1 { return [s16 / max(blen, 1), i] }
            return [s16 / max(blen, 1), -1]
        }
        var runs: [[MElem]] = [], cur: [MElem] = []
        for e in placed {
            let n = e.n!
            let beamable = n.pitch != "R" && n.len < 4
            if !cur.isEmpty && (!beamable || groupOf(e.start16) != groupOf(cur.last!.start16)) { runs.append(cur); cur = [] }
            if beamable { cur.append(e) } else { runs.append([e]) }
        }
        if !cur.isEmpty { runs.append(cur) }
        for run in runs {
            let notes = run.filter { $0.n!.pitch != "R" }
            if notes.isEmpty { for e in run { pg.rest(e.hx, top, sp, e.n!.len) }; continue }
            let avgPos = Double(notes.reduce(0) { $0 + $1.pos }) / Double(notes.count)
            let up = avgPos < 4
            for e in notes {
                let p = e.pos, hx = e.hx
                let hy = ypos(p)
                var lp = -2
                while lp >= p { pg.line(CGPoint(x: hx - 1.05 * sp, y: ypos(lp)), CGPoint(x: hx + 1.05 * sp, y: ypos(lp)), 0.6); lp -= 2 }
                lp = 10
                while lp <= p { pg.line(CGPoint(x: hx - 1.05 * sp, y: ypos(lp)), CGPoint(x: hx + 1.05 * sp, y: ypos(lp)), 0.6); lp += 2 }
                let ln = e.n!.len
                pg.head(hx, hy, sp, filled: ln < 8)
                if let acc = e.acc { pg.accidental(hx - 0.95 * sp - 1.55 * sp, hy, acc, sp) }
                if ln == 3 || ln == 6 || ln == 12 {
                    let dy: CGFloat = p % 2 == 0 ? -sp / 2 : 0
                    pg.dot(CGPoint(x: hx + 1.15 * sp, y: hy + dy), 0.2 * sp)
                }
                e.hy = hy
            }
            if notes.count == 1 || run.count == 1 {
                let e = notes[0]
                let ln = e.n!.len
                if ln >= 16 { continue }
                let up1 = e.pos < 4
                let sx = e.hx + (up1 ? 0.6 * sp : -0.6 * sp)
                let hy = e.hy!
                let sy = hy + (up1 ? -3.5 * sp : 3.5 * sp)
                pg.line(CGPoint(x: sx, y: hy - (up1 ? 0.1 * sp : -0.1 * sp)), CGPoint(x: sx, y: sy), 0.75)
                if ln < 4 { pg.flag(sx, sy, sp, up1, ln >= 2 ? 1 : 2) }
                continue
            }
            let by: CGFloat = up ? notes.map { $0.hy! }.min()! - 3.5 * sp : notes.map { $0.hy! }.max()! + 3.5 * sp
            var xs: [CGFloat] = []
            for e in notes {
                let sx = e.hx + (up ? 0.6 * sp : -0.6 * sp)
                pg.line(CGPoint(x: sx, y: e.hy!), CGPoint(x: sx, y: by), 0.75)
                xs.append(sx)
            }
            let bw = 0.5 * sp
            let s: CGFloat = up ? 1 : -1
            func beam(_ x1: CGFloat, _ x2: CGFloat, _ y: CGFloat) {
                pg.fillRect(CGRect(x: x1, y: y - (up ? 0 : bw), width: x2 - x1, height: bw))
            }
            beam(xs[0], xs[xs.count - 1], by)
            let y2 = by + s * 0.8 * sp
            for (i, e) in notes.enumerated() where e.n!.len == 1 {
                if i + 1 < notes.count && notes[i + 1].n!.len == 1 { beam(xs[i], xs[i + 1], y2) }
                else if !(i > 0 && notes[i - 1].n!.len == 1) {
                    let x1 = i == notes.count - 1 ? xs[i] - 1.2 * sp : xs[i]
                    let x2 = i == notes.count - 1 ? xs[i] : xs[i] + 1.2 * sp
                    beam(x1, x2, y2)
                }
            }
        }
        for (a, b) in zip(placed, placed.dropFirst()) {
            if b.n!.tie, let ay = a.hy, b.hy != nil {
                let below = a.pos < 4
                let yy = ay + (below ? 0.9 * sp : -0.9 * sp)
                pg.tie(a.hx + 0.6 * sp, b.hx - 0.6 * sp, yy, sp, below)
            }
        }
    }

    // ------------------------------------------------------------ rhythm box
    static let syll: [String: String] = ["D": "DUM", "T": "TAK", "K": "KA", "P": "PA", "-": "–", "": ""]

    static func wrapText(_ text: String, _ f: Face, _ size: CGFloat, _ maxw: CGFloat) -> [String] { Renderer.wrap(text, f, size, maxw) }

    static func textLines(_ r: Rhythm, _ maxw: CGFloat, _ k: CGFloat) -> [(String, Face, CGFloat, CGFloat)] {
        var out: [(String, Face, CGFloat, CGFloat)] = [("RHYTHM  ·  FRAME DRUM", .S, 8 * k, 8 * k * 1.7)]
        out.append((r.name, .B, 11.5 * k, 11.5 * k * 1.3))
        var meta: [String] = []
        if !r.meter.isEmpty { meta.append(r.meter) }
        if !r.grouping.isEmpty { meta.append("(\(r.grouping))") }
        if !r.tempo.isEmpty { meta.append(r.tempo) }
        for s in wrapText(meta.joined(separator: "   "), .R, 9 * k, maxw) { out.append((s, .R, 9 * k, 9 * k * 1.4)) }
        var extra: [String] = []
        if !r.practice.isEmpty {
            extra.append("MPA practice: " + r.practice.split(whereSeparator: { $0.isWhitespace }).map { $0 == "-" ? "–" : String($0) }.joined(separator: " ") + " (PA in place of TAK)")
        }
        if !r.confidence.isEmpty { extra.append(r.confidence.prefix(1).uppercased() + r.confidence.dropFirst() + (r.confidence.hasSuffix(".") ? "" : ".")) }
        for t in extra { for s in wrapText(t, .I, 7.6 * k, maxw) { out.append((s, .I, 7.6 * k, 7.6 * k * 1.38)) } }
        return out
    }

    /// The box plus its legend, rule and the 14 pt gap, as one block (render_pdf.py rhythm_box).
    static func rhythmBox(_ r: Rhythm, _ width: CGFloat) -> Block {
        let k: CGFloat = 1
        let cells = r.cells.map { ($0 == "." || $0 == "_") ? "" : $0 }
        let n = max(cells.count, 1)
        let textCol: CGFloat = 168 * k, clefW: CGFloat = 22 * k
        let area = width - textCol - clefW
        let cw = min(30 * k, area / CGFloat(n))
        let cellH: CGFloat = 15 * k, numH: CGFloat = 7 * k, spoonH: CGFloat = 9 * k, gap: CGFloat = 3 * k
        let beamH: CGFloat = 14 * k, lineGap: CGFloat = 9 * k, sylH: CGFloat = 10 * k
        let noteH = numH + cellH + spoonH + gap + beamH + lineGap + 4 * k + sylH
        let lines = textLines(r, textCol - 10 * k, k)
        let textH = lines.reduce(0) { $0 + $1.3 }
        let h = max(noteH, textH) + 4 * k
        let legend = "Frame drum staff: low line DUM (centre of the skin), high line TAK and KA (edge), x = PA, small note in ( ) = touch (ghost note). Cells as in MPA Academy: thick left line = accent, numbers under the cells restart on every accent."
        let lsize: CGFloat = 6.8
        let leg = wrapText(legend, .R, lsize, width)
        let lh = lsize * 1.35
        let total = h + CGFloat(leg.count) * lh + 6 + 14

        return Block(h: total) { pg, x, y in
            var yy = y
            for (s, f, size, lhh) in lines {
                yy += lhh
                pg.text(x, yy - lhh * 0.28, s, f, size, f == .S ? N.light : (f == .B ? N.ink : N.grey))
            }
            let gx = x + textCol + clefW
            let cy = y + numH
            var spoon = 0
            let acc = cells.map { $0 != "-" && $0 != "" }
            for (i, c) in cells.enumerated() {
                let cx0 = gx + CGFloat(i) * cw
                pg.strokeRect(CGRect(x: cx0, y: cy, width: cw, height: cellH), 0.6)
                if acc[i] { pg.fillRect(CGRect(x: cx0, y: cy, width: 2.4 * k, height: cellH)) }
                let lab = c == "-" ? "–" : c
                let lw = tw(lab, .S, 10.5 * k)
                pg.text(cx0 + cw / 2 - lw / 2 + (acc[i] ? 0.8 * k : 0), cy + cellH * 0.72, lab, .S, 10.5 * k, c != "-" ? N.ink : N.grey)
                let num = String(i + 1)
                pg.text(cx0 + cw / 2 - tw(num, .R, 6 * k) / 2, cy - 1.8 * k, num, .R, 6 * k, N.light)
                spoon = acc[i] ? 1 : spoon + 1
                let f: Face = spoon == 1 ? .B : .R
                let st = String(spoon)
                pg.text(cx0 + cw / 2 - tw(st, f, 7 * k) / 2, cy + cellH + 7.5 * k, st, f, 7 * k, spoon == 1 ? N.ink : N.light)
            }
            let hiY = cy + cellH + spoonH + gap + beamH
            let loY = hiY + lineGap
            let sx0 = gx - clefW + 2 * k, sx1 = gx + CGFloat(n) * cw
            pg.line(CGPoint(x: sx0, y: hiY), CGPoint(x: sx1, y: hiY), 0.6)
            pg.line(CGPoint(x: sx0, y: loY), CGPoint(x: sx1, y: loY), 0.6)
            for dx in [CGFloat(0), 3.2 * k] {
                pg.fillRect(CGRect(x: sx0 + 1.5 * k + dx, y: hiY - 2 * k, width: 1.6 * k, height: loY - hiY + 4 * k))
            }
            let mp = r.meter.split(separator: "/").map(String.init)
            if mp.count == 2 {
                let ts = 7.5 * k
                let tx = sx0 + 11.5 * k
                for (t, by) in [(mp[0], hiY - 0.6 * k), (mp[1], loY + ts * 0.72 + 0.4 * k)] {
                    pg.text(tx - tw(t, .B, ts) / 2, by, t, .B, ts, N.ink)
                }
            }
            pg.line(CGPoint(x: sx1 - 3.2 * k, y: hiY - 3 * k), CGPoint(x: sx1 - 3.2 * k, y: loY + 3 * k), 0.6)
            pg.fillRect(CGRect(x: sx1 - 1.6 * k, y: hiY - 3 * k, width: 1.6 * k, height: loY - hiY + 6 * k))
            for y2 in [hiY + lineGap * 0.3, hiY + lineGap * 0.7] { pg.dot(CGPoint(x: sx1 - 6 * k, y: y2), 0.9 * k) }

            let value = r.cell
            var groups = r.grouping.replacingOccurrences(of: " ", with: "").split(separator: "+").compactMap { Int($0) }
            if groups.reduce(0, +) != n {
                let per = max(1, value / 4)
                groups = Array(repeating: per, count: n / per)
            }
            let beamY = hiY - 13 * k
            var heads: [(CGFloat, CGFloat, String)?] = []
            for (i, c) in cells.enumerated() {
                let hx = gx + CGFloat(i) * cw + cw / 2
                if c == "" { heads.append(nil); continue }
                let hy = c == "D" ? loY : hiY
                if c == "-" {
                    pg.head(hx, hy, 5.2 * k, filled: true, scale: 0.62)
                    for side in [CGFloat(-1), 1] {
                        pg.bezier(CGPoint(x: hx + side * 3.4 * k, y: hy - 3.0 * k), CGPoint(x: hx + side * 4.6 * k, y: hy - 1.0 * k),
                                  CGPoint(x: hx + side * 4.6 * k, y: hy + 1.0 * k), CGPoint(x: hx + side * 3.4 * k, y: hy + 3.0 * k), 0.5, N.grey)
                    }
                } else if c == "P" { pg.xhead(hx, hy, 5.2 * k) }
                else { pg.head(hx, hy, 5.2 * k, filled: value != 2) }
                heads.append((hx, hy, c))
            }
            var stemX: [CGFloat?] = []
            for hd in heads {
                guard let (hx, hy, _) = hd else { stemX.append(nil); continue }
                let sx = hx + 3.0 * k
                pg.line(CGPoint(x: sx, y: hy - 0.4 * k), CGPoint(x: sx, y: beamY), 0.7)
                stemX.append(sx)
            }
            let nbeams = value == 16 ? 2 : (value == 8 ? 1 : 0)
            var start = 0
            for g in groups {
                let idx = (start..<min(start + g, n)).filter { $0 < stemX.count && stemX[$0] != nil }
                start += g
                if nbeams == 0 || idx.isEmpty { continue }
                for b in 0..<nbeams {
                    let by = beamY + CGFloat(b) * 3.2 * k
                    if idx.count == 1 { pg.flag(stemX[idx[0]]!, by, 4.4 * k, true, 1); continue }
                    pg.fillRect(CGRect(x: stemX[idx[0]]!, y: by, width: stemX[idx.last!]! - stemX[idx[0]]!, height: 1.9 * k))
                }
            }
            for (i, c) in cells.enumerated() where c == "" {
                pg.rest(gx + CGFloat(i) * cw + cw / 2, hiY - 2 * 4.5 * k + lineGap / 2, 4.5 * k, value > 0 ? 16 / value : 1)
            }
            let sylY = loY + 4 * k + sylH * 0.8
            for (i, c) in cells.enumerated() {
                let s = syll[c] ?? c
                if s.isEmpty { continue }
                let f: Face = (c != "-" && c != "") ? .B : .R
                let sz = 6.6 * k
                pg.text(gx + CGFloat(i) * cw + cw / 2 - tw(s, f, sz) / 2, sylY, s, f, sz, f == .B ? N.ink : N.grey)
            }
            for (i, l) in leg.enumerated() { pg.text(x, y + h + CGFloat(i) * lh + lsize, l, .R, lsize, L.label) }
            pg.rule(y + h + CGFloat(leg.count) * lh + 6)
        }
    }
}
