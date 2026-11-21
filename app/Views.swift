import SwiftUI
import PDFKit
import AppKit

struct Launch { static var tab = 0; static var shot: String? = nil }

struct TextSheetKind: Identifiable {
    enum Kind { case lyrics, translation, ocr }
    let id = UUID()
    var kind: Kind
    var title: String
    var help: String
    var text: String
}

// ---------------------------------------------------------------- the one window
struct ContentView: View {
    @EnvironmentObject var store: Store
    @StateObject var player = Player()
    @State var tab = Launch.tab
    @State var textSheet: TextSheetKind?

    var body: some View {
        HSplitView {
            SongList().frame(minWidth: 230, idealWidth: 260, maxWidth: 360)
            detail.frame(minWidth: 560)
        }
        .frame(minWidth: 860, minHeight: 540)
        .overlay(alignment: .topTrailing) { if store.needsPermission { PermissionsButton().padding(8) } }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            var urls: [URL] = []
            let group = DispatchGroup()
            for p in providers {
                group.enter()
                p.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    if let d = item as? Data, let u = URL(dataRepresentation: d, relativeTo: nil) { urls.append(u) }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                if let t = store.importFiles(urls, into: store.selected) {
                    textSheet = TextSheetKind(kind: .lyrics, title: "Lyrics from the dropped text", help: "A blank line starts a new section. Check the words, then add.", text: t)
                }
            }
            return true
        }
        .sheet(item: $textSheet) { k in
            TextSheet(kind: k) { text in apply(k.kind, text) }
        }
    }

    @ViewBuilder var detail: some View {
        if let i = store.index(of: store.selected) {
            VStack(spacing: 0) {
                HStack {
                    Picker("", selection: $tab) { Text("Edit").tag(0); Text("Preview").tag(1) }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 180)
                    Spacer()
                    Button("Make this PDF") {
                        if let u = store.makePDF(store.songs[i]) { store.status = "Made \(u.lastPathComponent) in \(store.pdfDir.path)" }
                    }
                    Button("Reveal in Finder") { store.reveal(store.pdfDir.appendingPathComponent(store.songs[i].pdfName)) }
                }.padding(8)
                Divider()
                if tab == 0 {
                    HSplitView {
                        SongEditor(song: $store.songs[i], suggestions: store.analysis[store.songs[i].id]?.chords ?? [], openText: { textSheet = $0 })
                            .frame(minWidth: 420)
                        if !store.songs[i].sources.images.isEmpty {
                            ImagePanel(song: store.songs[i], openText: { textSheet = $0 }).frame(minWidth: 240, idealWidth: 340)
                        }
                    }
                } else {
                    PreviewView(song: store.songs[i])
                }
                Divider()
                AudioBar(song: $store.songs[i], player: player)
            }
        } else {
            VStack(spacing: 8) {
                Text("No song selected").font(.title3)
                Text("Press New song, or choose a library folder with songs/*.json.").foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func apply(_ kind: TextSheetKind.Kind, _ text: String) {
        guard let i = store.index(of: store.selected) else { return }
        switch kind {
        case .lyrics, .ocr:
            let new = sectionsFromText(text)
            if new.isEmpty { return }
            let blank = store.songs[i].sections.allSatisfy { $0.lines.allSatisfy { $0.text.isEmpty } }
            if blank { store.songs[i].sections = new }
            else {
                var n = store.songs[i].sections.count
                for var s in new { n += 1; s.name = String(n); store.songs[i].sections.append(s) }
            }
        case .translation:
            let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var k = 0
            for si in store.songs[i].sections.indices {
                for li in store.songs[i].sections[si].lines.indices where !store.songs[i].sections[si].lines[li].text.isEmpty {
                    if k < lines.count { store.songs[i].sections[si].lines[li].translation = lines[k]; k += 1 }
                }
            }
            store.status = "Translation lines placed: \(k)."
        }
    }
}

struct PermissionsButton: View {
    var body: some View {
        Button("PERMISSIONS") {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!)
        }
        .buttonStyle(.borderedProminent).tint(.orange)
        .help("macOS has not allowed this app to open the library folder. Click to open the Files and Folders settings.")
    }
}

// ---------------------------------------------------------------- the song list: the first screen
struct SongList: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $store.selected) {
                ForEach(store.songs) { s in
                    Text("\(s.number)  \(s.title)")
                        .tag(s.id)
                        .contextMenu { Button("Move to Trash") { store.deleteSong(s.id) } }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("New song") { store.newSong() }
                    Button("Make PDFs") { store.makeAllPDFs() }.keyboardShortcut(.defaultAction)
                }
                if let f = store.lastPDFFolder {
                    Button("Reveal PDFs in Finder") { store.reveal(f) }.buttonStyle(.link)
                }
                Text(store.status).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text("Library: " + store.library.lastPathComponent).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    Button("Change...") { chooseFolder() }.buttonStyle(.link).font(.caption2)
                }
                Text("Drop pictures, a recording or a text file on the window.").font(.caption2).foregroundColor(.secondary)
            }.padding(10)
        }
    }

    func chooseFolder() {
        let p = NSOpenPanel()
        p.canChooseFiles = false; p.canChooseDirectories = true; p.canCreateDirectories = true
        p.message = "Choose the song library folder (it holds songs/*.json)"
        if p.runModal() == .OK, let u = p.url { store.setLibrary(u) }
    }
}

// ---------------------------------------------------------------- the editor
struct SongEditor: View {
    @Binding var song: Song
    let suggestions: [String]
    let openText: (TextSheetKind) -> Void

    func joined(_ get: @escaping () -> [String], _ set: @escaping ([String]) -> Void) -> Binding<String> {
        Binding(get: { get().joined(separator: "\n") },
                set: { set($0.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) })
    }

    @ViewBuilder func field(_ label: String, _ b: Binding<String>, width: CGFloat? = nil) -> some View {
        HStack {
            Text(label).frame(width: 70, alignment: .trailing).foregroundColor(.secondary)
            if let w = width { TextField("", text: b).frame(width: w) } else { TextField("", text: b) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { field("Number", $song.number, width: 120); field("Title", $song.title) }
                        field("Subtitle", $song.subtitle)
                        HStack { field("Key", $song.key); field("Tempo", $song.tempo) }
                        field("Rhythm", $song.rhythm)
                    }.padding(4)
                }
                HStack {
                    Button("Add lyrics from text...") {
                        openText(TextSheetKind(kind: .lyrics, title: "Lyrics", help: "Paste the words. A blank line starts a new section, every other line is one sung line.", text: ""))
                    }
                    Button("Add translation from text...") {
                        openText(TextSheetKind(kind: .translation, title: "English translation", help: "One translation line for each lyric line, in order. Typed by hand: nothing here is machine translated.", text: ""))
                    }
                    Spacer()
                    Button("Add section") { song.sections.append(SongSection(name: String(song.sections.count + 1), lines: [SongLine()])) }
                }
                ForEach($song.sections) { $sec in
                    SectionEditor(section: $sec, suggestions: suggestions) { song.sections.removeAll { $0.id == sec.id } }
                }
                GroupBox("Instrumental rows at the top of the guitar page") {
                    VStack(alignment: .leading) {
                        ForEach($song.play) { $r in
                            HStack {
                                TextField("Label (Intro)", text: $r.label).frame(width: 160)
                                TextField("| Dm | G |", text: $r.chords)
                                Button { song.play.removeAll { $0.id == r.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                            }
                        }
                        Button("Add row") { song.play.append(PlayRow()) }
                    }.padding(4)
                }
                GroupBox("Form (one step per line)") {
                    TextEditor(text: joined({ song.arrangement }, { song.arrangement = $0 }))
                        .font(.body).frame(minHeight: 70)
                }
                GroupBox("Notes (one per line, shown in italics under FORM)") {
                    TextEditor(text: joined({ song.notes }, { song.notes = $0 }))
                        .font(.body).frame(minHeight: 50)
                }
            }.padding(12)
        }
    }
}

struct SectionEditor: View {
    @Binding var section: SongSection
    let suggestions: [String]
    let onDelete: () -> Void
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Section").foregroundColor(.secondary)
                    TextField("name (1, Chorus...)", text: $section.name).frame(width: 150)
                    Spacer()
                    Button("Add line") { section.lines.append(SongLine()) }
                    Button("Delete section", role: .destructive) { onDelete() }
                }
                ForEach($section.lines) { $ln in
                    LineEditor(line: $ln, suggestions: suggestions) { section.lines.removeAll { $0.id == ln.id } }
                    Divider()
                }
            }.padding(4)
        }
    }
}

struct LineEditor: View {
    @Binding var line: SongLine
    let suggestions: [String]
    let onDelete: () -> Void
    var repeatText: Binding<String> { Binding(get: { line.repeatMark ?? "" }, set: { line.repeatMark = $0.isEmpty ? nil : $0 }) }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("Original line", text: $line.text)
                TextField("English translation", text: $line.translation)
                TextField("x2", text: repeatText).frame(width: 44)
                Button { onDelete() } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
            }
            if !line.text.isEmpty { ChordLine(line: $line, suggestions: suggestions) }
        }
        .onChange(of: line.text) { _, new in
            let n = new.precomposedStringWithCanonicalMapping
            if n != new { line.text = n; return }
            let count = n.unicodeScalars.count
            for i in line.chords.indices where line.chords[i].at_char > count { line.chords[i].at_char = count }
        }
    }
}

// ---------------------------------------------------------------- chords above the characters
struct ChordEdit: Identifiable {
    let id = UUID()
    var pos: Int
    var chord: String
    var confirmed: Bool
    var existed: Bool
    var fromSuggestion = false
}

struct ChordLine: View {
    @Binding var line: SongLine
    let suggestions: [String]
    @State var edit: ChordEdit?

    var chars: [String] { line.text.unicodeScalars.map { String($0) } }

    func chordAt(_ i: Int) -> ChordMark? { line.chords.first { $0.at_char == i } }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(0...chars.count, id: \.self) { i in
                    VStack(spacing: 0) {
                        Text(chordAt(i)?.chord ?? " ")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor((chordAt(i)?.confirmed ?? true) ? Color(red: 0.69, green: 0.23, blue: 0.18) : Color.gray)
                            .fixedSize().frame(width: 9, height: 16, alignment: .leading)
                        Text(i < chars.count ? (chars[i] == " " ? "\u{00B7}" : chars[i]) : "|")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(i < chars.count && chars[i] != " " ? .primary : Color.gray.opacity(0.5))
                            .frame(width: 9, height: 16)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let c = chordAt(i) { edit = ChordEdit(pos: i, chord: c.chord, confirmed: c.confirmed, existed: true) }
                        else { edit = ChordEdit(pos: i, chord: "", confirmed: true, existed: false) }
                    }
                }
            }
        }
        .help("Click a character to put a chord above it. Grey = not confirmed.")
        .sheet(item: $edit) { e in
            ChordSheet(edit: e, context: context(e.pos), suggestions: suggestions) { result in
                line.chords.removeAll { $0.at_char == e.pos }
                if let r = result, !r.chord.trimmingCharacters(in: .whitespaces).isEmpty {
                    line.chords.append(ChordMark(at_char: e.pos, chord: r.chord.trimmingCharacters(in: .whitespaces),
                                                 source: r.fromSuggestion ? "audio" : "manual", confirmed: r.confirmed))
                    line.chords.sort { $0.at_char < $1.at_char }
                }
            }
        }
    }

    func context(_ pos: Int) -> String {
        let c = chars
        let before = c[max(0, pos - 8)..<min(pos, c.count)].joined()
        let after = c[min(pos, c.count)..<min(pos + 8, c.count)].joined()
        return "\(before)|\(after)"
    }
}

struct ChordSheet: View {
    @State var edit: ChordEdit
    let context: String
    let suggestions: [String]
    let done: (ChordEdit?) -> Void
    @Environment(\.dismiss) var dismiss

    init(edit: ChordEdit, context: String, suggestions: [String], done: @escaping (ChordEdit?) -> Void) {
        _edit = State(initialValue: edit); self.context = context; self.suggestions = suggestions; self.done = done
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chord at  \(context)").font(.headline)
            TextField("Am, E7, Bb, Em7 ...", text: $edit.chord).textFieldStyle(.roundedBorder).frame(width: 240)
                .onSubmit { done(edit); dismiss() }
            Toggle("Confirmed (on the board, or checked by ear). Off draws it grey.", isOn: $edit.confirmed)
            if !suggestions.isEmpty {
                Text("From the recording analysis, not certain:").font(.caption).foregroundColor(.secondary)
                HStack { ForEach(suggestions.prefix(8), id: \.self) { s in
                    Button(s) { edit.chord = s; edit.confirmed = false; edit.fromSuggestion = true }
                } }
            }
            HStack {
                Button("Cancel") { dismiss() }
                if edit.existed { Button("Remove chord", role: .destructive) { done(nil); dismiss() } }
                Spacer()
                Button("Save") { done(edit); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(16).frame(minWidth: 380)
    }
}

// ---------------------------------------------------------------- pictures beside the editor
struct ImagePanel: View {
    @EnvironmentObject var store: Store
    let song: Song
    let openText: (TextSheetKind) -> Void
    @State var sel: String = ""
    @State var zoom: CGFloat = 1
    @State var busy = false
    @State var message = ""

    var current: String { song.sources.images.contains(sel) ? sel : (song.sources.images.first ?? "") }

    var body: some View {
        VStack(spacing: 6) {
            Picker("", selection: Binding(get: { current }, set: { sel = $0 })) {
                ForEach(song.sources.images, id: \.self) { Text($0).tag($0) }
            }.labelsHidden()
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical]) {
                    if let u = store.imageURL(current), let img = NSImage(contentsOf: u) {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(width: max(100, geo.size.width - 16) * zoom)
                    } else {
                        Text("\(current) is not in the library folder.").foregroundColor(.secondary).padding()
                    }
                }
            }
            HStack {
                Slider(value: $zoom, in: 0.5...4)
                Button(busy ? "Reading..." : "Read text (OCR)") { ocr() }.disabled(busy)
            }
            if !message.isEmpty { Text(message).font(.caption).foregroundColor(.secondary) }
        }.padding(8)
    }

    func ocr() {
        guard let u = store.imageURL(current) else { message = "Picture not found."; return }
        busy = true; message = ""
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try OCR.lines(in: u) }
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let lines):
                    if lines.isEmpty { message = "No text found in this picture." }
                    else { openText(TextSheetKind(kind: .ocr, title: "Text read from \(current)", help: "Draft only: compare with the picture and correct before adding. Chords written on a flipchart are not read reliably; place them by hand.", text: lines.joined(separator: "\n"))) }
                case .failure(let e): message = e.localizedDescription
                }
            }
        }
    }
}

struct TextSheet: View {
    let kind: TextSheetKind
    let onAdd: (String) -> Void
    @State var text: String
    @Environment(\.dismiss) var dismiss
    init(kind: TextSheetKind, onAdd: @escaping (String) -> Void) { self.kind = kind; self.onAdd = onAdd; _text = State(initialValue: kind.text) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.title).font(.headline)
            Text(kind.help).font(.caption).foregroundColor(.secondary)
            TextEditor(text: $text).font(.system(size: 13)).frame(minWidth: 480, minHeight: 300)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add to song") { onAdd(text); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(16)
    }
}

// ---------------------------------------------------------------- PDF preview
struct PreviewView: View {
    let song: Song
    var body: some View {
        switch Result(catching: { try Renderer.render(song) }) {
        case .success(let r): PDFKitView(data: r.data).overlay(alignment: .bottomTrailing) {
            Text("page 2: \(r.guitarColumns) column(s), size \(Int((r.guitarScale * 100).rounded())) %").font(.caption2).padding(6).foregroundColor(.secondary)
        }
        case .failure(let e): Text(e.localizedDescription).foregroundColor(.red).padding().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct PDFKitView: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true; v.displayMode = .singlePageContinuous; v.displayDirection = .vertical
        v.document = PDFDocument(data: data)
        return v
    }
    func updateNSView(_ v: PDFView, context: Context) {
        let page = v.currentPage.flatMap { v.document?.index(for: $0) } ?? 0
        v.document = PDFDocument(data: data)
        if let p = v.document?.page(at: page) { v.go(to: p) }
    }
}

// ---------------------------------------------------------------- recording: play, loop, analyse
struct AudioBar: View {
    @EnvironmentObject var store: Store
    @Binding var song: Song
    @ObservedObject var player: Player
    @State var running = false
    @State var message = ""
    @State var analyser: Analyser?

    var url: URL? { song.sources.audio.flatMap { store.audioURL($0) } }

    func fmt(_ t: Double) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if song.sources.audio == nil {
                Text("No recording yet. Drop an m4a, mp3 or wav on the window.").font(.caption).foregroundColor(.secondary)
            } else if url == nil {
                Text("Recording \(song.sources.audio ?? "") is not in the library folder.").font(.caption).foregroundColor(.secondary)
            } else {
                HStack {
                    Button { player.toggle() } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill") }
                    Text(fmt(player.time)).monospacedDigit().font(.caption)
                    Slider(value: Binding(get: { player.time }, set: { player.seek($0) }), in: 0...max(player.duration, 1))
                    Text(fmt(player.duration)).monospacedDigit().font(.caption)
                }
                HStack {
                    Button("Loop start") { player.setA() }
                    Button("Loop end") { player.setB() }
                    Toggle("Loop", isOn: $player.loopOn).disabled(player.loopA == nil || player.loopB == nil)
                    Button("Clear") { player.clearLoop() }
                    if let a = player.loopA { Text("from \(fmt(a))").font(.caption) }
                    if let b = player.loopB { Text("to \(fmt(b))").font(.caption) }
                    Spacer()
                    if running { Button("Stop analysis") { analyser?.cancelled = true; analyser?.process?.terminate() } }
                    else { Button("Analyse...") { analyse() }.help("Optional: separates the instruments and suggests tempo, key and chords. Needs the repo's Python tools.") }
                }
            }
            if let e = player.error { Text(e).font(.caption).foregroundColor(.red) }
            if !message.isEmpty { Text(message).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
            if let a = store.analysis[song.id] {
                HStack {
                    Button("Use key and tempo (unconfirmed)") {
                        if let k = a.keys.first { song.key = k + " (unconfirmed)" }
                        if let t = a.tempo { song.tempo = "~\(Int(t)) BPM (unconfirmed)" }
                    }
                    Text("Chord suggestions appear in the chord box, marked grey.").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .onAppear { player.load(url) }
        .onChange(of: song.id) { _, _ in player.load(url); message = "" }
        .onChange(of: song.sources.audio) { _, _ in player.load(url) }
    }

    func analyse() {
        guard let u = url else { return }
        let a = Analyser()
        analyser = a; running = true; message = "Checking the tools..."
        let id = song.id, lib = store.library
        DispatchQueue.global(qos: .userInitiated).async {
            let r = a.analyse(audio: u, library: lib) { m in message = m }
            DispatchQueue.main.async {
                running = false
                switch r {
                case .success(let res): store.analysis[id] = res; message = res.summary
                case .failure(let e): message = e.localizedDescription
                }
            }
        }
    }
}
