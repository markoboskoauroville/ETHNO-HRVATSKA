import AppKit
import CoreText
import CoreGraphics

// Pure Swift port of tools/render_pdf.py (numbers from songs/SCHEMA.md). A4 portrait, two pages:
// page 1 for singers (lyrics + translation), page 2 for the guitarist (chords above the words, form at the bottom).
// y grows downwards: the context is flipped once per page.

enum Face: String, CaseIterable { case R = "Regular", I = "Italic", S = "Semibold", B = "Bold", sym = "Symbols" }

final class Fonts {
    static let shared = Fonts()
    private var descriptors: [Face: CTFontDescriptor] = [:]
    private var cache: [String: CTFont] = [:]
    var missing: [String] = []

    init() {
        let bundleDir = Bundle.main.resourceURL?.appendingPathComponent("fonts")
        let repoDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer/ETHNO-HRVATSKA/fonts")
        for f in Face.allCases where f != .sym {
            let name = "OpenSans-\(f.rawValue).ttf"
            var found = false
            for dir in [bundleDir, repoDir].compactMap({ $0 }) {
                let url = dir.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: url.path),
                   let arr = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor], let d = arr.first {
                    descriptors[f] = d; found = true; break
                }
            }
            if !found { missing.append(name) }
        }
    }

    func font(_ f: Face, _ size: CGFloat) -> CTFont {
        let key = "\(f.rawValue)\(size)"
        if let c = cache[key] { return c }
        let ft: CTFont
        if f == .sym { ft = CTFontCreateWithName("Apple Symbols" as CFString, size, nil) }
        else if let d = descriptors[f] { ft = CTFontCreateWithFontDescriptor(d, size, nil) }
        else { ft = CTFontCreateWithName("Helvetica" as CFString, size, nil) }
        cache[key] = ft
        return ft
    }

    /// Text as one CTLine. The characters of the note symbols (U+2669, U+266A) are not in Open Sans: they come from
    /// Apple Symbols at 1.25 x the size, same baseline (SCHEMA.md section 3).
    func line(_ s: String, _ f: Face, _ size: CGFloat, _ color: CGColor = CGColor(gray: 0, alpha: 1)) -> CTLine {
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
        let colorKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
        let out = NSMutableAttributedString()
        var run = "", runSym = false
        func flush() {
            if run.isEmpty { return }
            let ft = runSym ? font(.sym, size * 1.25) : font(f, size)
            out.append(NSAttributedString(string: run, attributes: [fontKey: ft, colorKey: color]))
            run = ""
        }
        for ch in s {
            let isSym = f != .sym && (ch == "\u{2669}" || ch == "\u{266A}")
            if isSym != runSym { flush(); runSym = isSym }
            run.append(ch)
        }
        flush()
        return CTLineCreateWithAttributedString(out)
    }

    func width(_ s: String, _ f: Face, _ size: CGFloat) -> CGFloat {
        if s.isEmpty { return 0 }
        return CGFloat(CTLineGetTypographicBounds(line(s, f, size), nil, nil, nil))
    }
}

enum L {   // layout numbers, points
    static let pageW: CGFloat = 595.28, pageH: CGFloat = 841.89
    static let mLeft: CGFloat = 54, mRight: CGFloat = 54, mTop: CGFloat = 54
    static let contentW = pageW - mLeft - mRight
    static let gutter: CGFloat = 22
    static let footerY = pageH - 28
    static func hex(_ h: String) -> CGColor {
        let v = UInt32(h.dropFirst(), radix: 16) ?? 0
        return CGColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
    static let ink = hex("#111111"), sub = hex("#666666"), trans = hex("#6A6A6A"), label = hex("#A0A0A0")
    static let rule = hex("#D0D0D0"), chord = hex("#B03A2E"), chordGrey = hex("#A8A8A8"), foot = hex("#B0B0B0")
    static let title: CGFloat = 22, subtitle: CGFloat = 10, info: CGFloat = 9.5, tag: CGFloat = 9
    static let sLyric: CGFloat = 12.5, sTrans: CGFloat = 10.5, sLabel: CGFloat = 8, sRepeat: CGFloat = 10
    static let gChord: CGFloat = 10.5, gLyric: CGFloat = 12, gTrans: CGFloat = 8.8, gLabel: CGFloat = 8, gPlay: CGFloat = 9.5
    static let form: CGFloat = 8.5, footer: CGFloat = 7.5
    static let chordGap: CGFloat = 5, minShrink: CGFloat = 0.62
    static let scaleSteps: [CGFloat] = (0..<16).map { 1.0 - 0.02 * CGFloat($0) }
}

final class Pg {
    let ctx: CGContext
    let fonts = Fonts.shared
    init(_ ctx: CGContext) { self.ctx = ctx }
    func text(_ x: CGFloat, _ y: CGFloat, _ s: String, _ f: Face, _ size: CGFloat, _ color: CGColor) {
        guard !s.isEmpty else { return }
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(fonts.line(s, f, size, color), ctx)
        ctx.restoreGState()
    }
    func rtext(_ xr: CGFloat, _ y: CGFloat, _ s: String, _ f: Face, _ size: CGFloat, _ color: CGColor) {
        text(xr - fonts.width(s, f, size), y, s, f, size, color)
    }
    func rule(_ y: CGFloat) {
        ctx.saveGState()
        ctx.setStrokeColor(L.rule); ctx.setLineWidth(0.6)
        ctx.move(to: CGPoint(x: L.mLeft, y: y)); ctx.addLine(to: CGPoint(x: L.pageW - L.mRight, y: y)); ctx.strokePath()
        ctx.restoreGState()
    }
}

struct Block { var h: CGFloat; var draw: (Pg, CGFloat, CGFloat) -> Void }

enum Renderer {
    static func width(_ s: String, _ f: Face, _ size: CGFloat) -> CGFloat { Fonts.shared.width(s, f, size) }

    static func fit(_ s: String, _ f: Face, _ size: CGFloat, _ maxw: CGFloat) -> CGFloat {
        let w = width(s, f, size)
        if w <= maxw { return size }
        return max(size * L.minShrink, size * maxw / w)
    }

    static func infoLine(_ s: Song) -> String {
        var parts: [String] = []
        if !s.key.isEmpty { parts.append("Key \(s.key)") }
        if !s.tempo.isEmpty { parts.append("Tempo \(s.tempo)") }
        if !s.rhythmText.isEmpty { parts.append("Rhythm \(s.rhythmText)") }
        return parts.joined(separator: "   ·   ")
    }

    static func header(_ p: Pg, _ song: Song) -> CGFloat {
        var y = L.mTop + L.title * 0.9
        let title = "\(song.number)  \(song.title)"
        p.text(L.mLeft, y, title, .B, fit(title, .B, L.title, L.contentW), L.ink)
        y += 16
        p.text(L.mLeft, y, song.subtitle, .R, fit(song.subtitle, .R, L.subtitle, L.contentW), L.sub)
        let info = infoLine(song)
        if !info.isEmpty { y += 14; p.text(L.mLeft, y, info, .R, fit(info, .R, L.info, L.contentW), L.sub) }
        y += 10
        p.rule(y)
        return y + 18
    }

    // ---------------------------------------------------------------- singers page
    static func singersBlocks(_ song: Song, _ k: CGFloat) -> [Block] {
        let colw = (L.contentW - L.gutter) / 2
        var blocks: [Block] = []
        for sec in song.sections {
            enum Item { case label(CGFloat, String); case line(CGFloat, SongLine) }
            var items: [Item] = []
            var h: CGFloat = 0
            if !sec.name.isEmpty { items.append(.label(h, sec.name)); h += L.sLabel * k * 1.9 }
            for ln in sec.lines { items.append(.line(h, ln)); h += L.sLyric * k * 1.42 }
            h += 9 * k
            let its = items
            blocks.append(Block(h: h) { p, x, y in
                for it in its {
                    switch it {
                    case .label(let dy, let name):
                        p.text(x, y + dy + L.sLabel * k, name.uppercased(), .S, L.sLabel * k, L.label)
                    case .line(let dy, let o):
                        let base = y + dy + L.sLyric * k
                        let rep = o.repeatMark ?? ""
                        let repw = rep.isEmpty ? 0 : width(rep, .S, L.sRepeat * k) + 6
                        let ls = fit(o.text, .R, L.sLyric * k, colw - repw)
                        p.text(x, base, o.text, .R, ls, L.ink)
                        if !rep.isEmpty { p.text(x + width(o.text, .R, ls) + 6, base, rep, .S, L.sRepeat * k, L.label) }
                        let ts = fit(o.translation, .I, L.sTrans * k, colw)
                        p.text(x + colw + L.gutter, base, o.translation, .I, ts, L.trans)
                    }
                }
            })
        }
        return blocks
    }

    // ---------------------------------------------------------------- guitar page
    static func prefixWidth(_ text: String, _ atChar: Int, _ f: Face, _ size: CGFloat) -> CGFloat {
        let scalars = text.unicodeScalars
        let n = max(0, min(atChar, scalars.count))
        var s = String.UnicodeScalarView()
        s.append(contentsOf: scalars.prefix(n))
        return width(String(s), f, size)
    }

    static func chordPositions(_ text: String, _ chords: [ChordMark], _ x: CGFloat, _ size: CGFloat, _ csize: CGFloat) -> [(CGFloat, ChordMark)] {
        var out: [(CGFloat, ChordMark)] = []
        var prevEnd: CGFloat = -1e9
        let count = text.unicodeScalars.count
        for c in chords.sorted(by: { $0.at_char < $1.at_char }) {
            var cx = x + prefixWidth(text, c.at_char, .R, size)
            if c.at_char >= count { cx += size * 0.35 }
            cx = max(cx, prevEnd + L.chordGap)
            out.append((cx, c))
            prevEnd = cx + width(c.chord, .B, csize)
        }
        return out
    }

    static func guitarBlocks(_ song: Song, _ k: CGFloat, _ colw: CGFloat) -> [Block] {
        var seen = Set<String>()
        var blocks: [Block] = []
        for sec in song.sections {
            let n = sec.lines.count
            for (li, ln) in sec.lines.enumerated() {
                var h: CGFloat = 0
                let label: String? = (li == 0 && !sec.name.isEmpty) ? sec.name : nil
                if label != nil { h += L.gLabel * k * 1.9 }
                let showT = !seen.contains(ln.text) && !ln.translation.isEmpty
                seen.insert(ln.text)
                if !ln.chords.isEmpty { h += L.gChord * k * 1.08 }
                let top = h
                h += L.gLyric * k * 1.14
                if showT { h += L.gTrans * k * 1.25 }
                h += 2.5 * k
                if li == n - 1 { h += 7 * k }
                blocks.append(Block(h: h) { p, x, y in
                    if let label = label { p.text(x, y + L.gLabel * k, label.uppercased(), .S, L.gLabel * k, L.label) }
                    let base = y + top + L.gLyric * k * 0.95
                    let rep = ln.repeatMark ?? ""
                    let repw = rep.isEmpty ? 0 : width(rep, .S, L.sRepeat * k) + 6
                    let ls = fit(ln.text, .R, L.gLyric * k, colw - repw - 30)
                    let csize = L.gChord * k
                    for (cx, c) in chordPositions(ln.text, ln.chords, x, ls, csize) {
                        p.text(cx, base - L.gLyric * k * 1.06, c.chord, .B, csize, c.confirmed ? L.chord : L.chordGrey)
                    }
                    p.text(x, base, ln.text, .R, ls, L.ink)
                    if !rep.isEmpty { p.text(x + width(ln.text, .R, ls) + 6, base, rep, .S, L.sRepeat * k, L.label) }
                    if showT {
                        p.text(x, base + L.gTrans * k * 1.25, ln.translation, .I, fit(ln.translation, .I, L.gTrans * k, colw), L.trans)
                    }
                })
            }
        }
        return blocks
    }

    static func playBlock(_ song: Song, _ k: CGFloat) -> Block {
        let rows = song.play
        if rows.isEmpty { return Block(h: 0) { _, _, _ in } }
        let lh = L.gPlay * k * 1.55
        return Block(h: CGFloat(rows.count) * lh + 8 * k) { p, x, y in
            for (i, r) in rows.enumerated() {
                let b = y + CGFloat(i) * lh + L.gPlay * k
                let lab = r.label + ":"
                p.text(x, b, lab, .S, L.gPlay * k, L.sub)
                let cx = x + width(lab, .S, L.gPlay * k) + 6
                p.text(cx, b, r.chords, .B, fit(r.chords, .B, L.gPlay * k, L.contentW - (cx - x)), L.chord)
            }
        }
    }

    static func wrap(_ text: String, _ f: Face, _ size: CGFloat, _ maxw: CGFloat) -> [String] {
        var lines: [String] = [], cur = ""
        for w in text.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
            let t = cur.isEmpty ? w : cur + " " + w
            if width(t, f, size) <= maxw || cur.isEmpty { cur = t } else { lines.append(cur); cur = w }
        }
        if !cur.isEmpty { lines.append(cur) }
        return lines
    }

    static func formBlock(_ song: Song, _ k: CGFloat) -> Block {
        let size = L.form * k, lh = size * 1.38
        let colw = (L.contentW - L.gutter) / 2
        var bullets: [String] = []
        for a in song.arrangement {
            for (i, w) in wrap(a, .R, size, colw - 10).enumerated() { bullets.append((i == 0 ? "•  " : "    ") + w) }
        }
        var half = (bullets.count + 1) / 2
        while half > 0 && half < bullets.count && bullets[half].hasPrefix("    ") { half += 1 }
        var legend: [String] = []
        if song.sections.contains(where: { $0.lines.contains(where: { $0.chords.contains(where: { !$0.confirmed }) }) }) {
            legend.append("Grey chords are not on the board or not confirmed by the recording: check them by ear.")
        }
        for n in song.notes where !n.contains("Grey chords") { legend.append(n) }
        let leg = legend.flatMap { wrap($0, .I, size, L.contentW) }
        let rows = max(half, bullets.count - half)
        let h = (bullets.isEmpty ? 0 : CGFloat(1 + rows) * lh) + CGFloat(leg.count) * lh + 8 * k
        let hb = half, rw = rows
        return Block(h: h) { p, x, y in
            p.rule(y - 2)
            var yy = y + 6 * k + size
            if !bullets.isEmpty {
                p.text(x, yy, "FORM", .S, size, L.label)
                yy += lh
                for (i, b) in bullets.enumerated() {
                    let col = i < hb ? 0 : 1, row = i < hb ? i : i - hb
                    p.text(x + CGFloat(col) * (colw + L.gutter), yy + CGFloat(row) * lh, b, .R, size, L.sub)
                }
                yy += CGFloat(rw) * lh
            }
            for (i, w) in leg.enumerated() { p.text(x, yy + CGFloat(i) * lh, w, .I, size, L.sub) }
        }
    }

    // ---------------------------------------------------------------- packing
    static func pack(_ blocks: [Block], _ avail: CGFloat, _ ncols: Int) -> [[Block]]? {
        if blocks.isEmpty { return [[]] }
        let hs = blocks.map { $0.h }
        let total = hs.reduce(0, +)
        if hs.max()! > avail { return nil }
        var target = max(total / CGFloat(ncols), hs.max()!)
        while target <= avail + 1e-6 {
            var cols: [[Block]] = [], cur: [Block] = []
            var h: CGFloat = 0
            for b in blocks {
                if h + b.h > target + 1e-6 && !cur.isEmpty { cols.append(cur); cur = []; h = 0 }
                cur.append(b); h += b.h
            }
            cols.append(cur)
            if cols.count <= ncols { return cols }
            target += 2
        }
        return nil
    }

    static func singersBlocksStacked(_ song: Song, _ k: CGFloat, _ colw: CGFloat) -> [Block] {
        var blocks: [Block] = []
        for sec in song.sections {
            let n = sec.lines.count
            for (li, ln) in sec.lines.enumerated() {
                var h: CGFloat = 0
                let label: String? = (li == 0 && !sec.name.isEmpty) ? sec.name : nil
                if label != nil { h += L.sLabel * k * 1.9 }
                let top = h
                h += L.sLyric * k * 1.18 + L.sTrans * k * 0.95 * 1.25 + 2.5 * k
                if li == n - 1 { h += 7 * k }
                blocks.append(Block(h: h) { p, x, y in
                    if let label = label { p.text(x, y + L.sLabel * k, label.uppercased(), .S, L.sLabel * k, L.label) }
                    let base = y + top + L.sLyric * k
                    let rep = ln.repeatMark ?? ""
                    let repw = rep.isEmpty ? 0 : width(rep, .S, L.sRepeat * k) + 6
                    let ls = fit(ln.text, .R, L.sLyric * k, colw - repw)
                    p.text(x, base, ln.text, .R, ls, L.ink)
                    if !rep.isEmpty { p.text(x + width(ln.text, .R, ls) + 6, base, rep, .S, L.sRepeat * k, L.label) }
                    let ts = L.sTrans * k * 0.95
                    p.text(x, base + ts * 1.25, ln.translation, .I, fit(ln.translation, .I, ts, colw), L.trans)
                })
            }
        }
        return blocks
    }

    static func melodyBlock(_ song: Song) -> Block {
        guard let m = song.melody else { return Block(h: 0) { _, _, _ in } }
        let b = Notation.layoutMelody(m, L.contentW, 1)
        return Block(h: b.h + 14, draw: b.draw)
    }

    static func drawCols(_ p: Pg, _ cols: [[Block]], _ y0: CGFloat, _ colw: CGFloat) {
        for (ci, col) in cols.enumerated() {
            let x = L.mLeft + CGFloat(ci) * (colw + L.gutter)
            var y = y0
            for b in col { b.draw(p, x, y); y += b.h }
        }
    }

    struct Result { var data: Data; var guitarColumns: Int; var guitarScale: CGFloat; var warnings: [String] }

    /// Render both pages to PDF data. Throws a plain message when a page cannot fit.
    static func render(_ song: Song) throws -> Result {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: L.pageW, height: L.pageH)
        let info: [CFString: Any] = [
            kCGPDFContextTitle: "\(song.number) \(song.title)",
            kCGPDFContextAuthor: "Etno orkestar · ETHNO-HRVATSKA",
            kCGPDFContextSubject: "Lyrics, translation and chords",
            kCGPDFContextCreator: "Ethno Song Sheets (Mantra)",
        ]
        guard let consumer = CGDataConsumer(data: data), let ctx = CGContext(consumer: consumer, mediaBox: &box, info as CFDictionary) else {
            throw RenderError.msg("Could not start the PDF.")
        }
        func begin() -> Pg {
            ctx.beginPDFPage(nil)
            ctx.translateBy(x: 0, y: L.pageH); ctx.scaleBy(x: 1, y: -1)
            return Pg(ctx)
        }
        // page 1
        var p = begin()
        var y0 = header(p, song)
        let mb = melodyBlock(song)
        var avail = L.footerY - 18 - y0 - mb.h
        let half = (L.contentW - L.gutter) / 2
        var singers: (Int, CGFloat, [[Block]])? = nil
        var tries: [(Int, CGFloat)] = L.scaleSteps.prefix(11).map { (1, $0) }
        tries += L.scaleSteps.map { (2, $0) }
        for (nc, k) in tries {
            let blocks = nc == 1 ? singersBlocks(song, k) : singersBlocksStacked(song, k, half)
            if let c = pack(blocks, avail, nc) { singers = (nc, k, c); break }
        }
        guard let sg = singers else { throw RenderError.msg("\(song.title): the singers page does not fit even at the smallest size. Shorten the song or split it.") }
        mb.draw(p, L.mLeft, y0)
        drawCols(p, sg.2, y0 + mb.h, sg.0 == 1 ? L.contentW : half)
        ctx.endPDFPage()
        // page 2
        p = begin()
        y0 = header(p, song)
        if let r = song.rhythmObj {
            let rb = Notation.rhythmBox(r, L.contentW)
            rb.draw(p, L.mLeft, y0)
            y0 += rb.h
        }
        var candidates: [(Int, CGFloat)] = L.scaleSteps.prefix(5).map { (1, $0) }
        candidates += L.scaleSteps.prefix(13).map { (2, $0) }
        candidates += L.scaleSteps.map { (3, $0) }
        var chosen: (Int, CGFloat, CGFloat, Block, Block, [[Block]])? = nil
        for (ncols, k) in candidates {
            let colw = (L.contentW - L.gutter * CGFloat(ncols - 1)) / CGFloat(ncols)
            let pb = playBlock(song, k)
            let fb = formBlock(song, min(1.0, k + 0.05))
            avail = L.footerY - 16 - y0 - pb.h - fb.h - 10
            if let cols = pack(guitarBlocks(song, k, colw), avail, ncols) { chosen = (ncols, colw, k, pb, fb, cols); break }
        }
        guard let ch = chosen else { throw RenderError.msg("\(song.title): the guitar page does not fit. Shorten the song or split it.") }
        ch.3.draw(p, L.mLeft, y0)
        drawCols(p, ch.5, y0 + ch.3.h, ch.1)
        ch.4.draw(p, L.mLeft, L.footerY - 16 - ch.4.h)
        ctx.endPDFPage()
        ctx.closePDF()
        var warn: [String] = []
        if !Fonts.shared.missing.isEmpty { warn.append("Open Sans missing: " + Fonts.shared.missing.joined(separator: ", ")) }
        return Result(data: data as Data, guitarColumns: ch.0, guitarScale: ch.2, warnings: warn)
    }
}

enum RenderError: Error, LocalizedError {
    case msg(String)
    var errorDescription: String? { if case .msg(let s) = self { return s } else { return nil } }
}
