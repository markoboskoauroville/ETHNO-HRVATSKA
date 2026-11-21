import AppKit
import Combine
import UniformTypeIdentifiers

/// The song library: a folder with songs/*.json, PDF/ for the output, recordings and images beside them.
final class Store: ObservableObject {
    @Published var library: URL
    @Published var songs: [Song] = []
    @Published var selected: UUID?
    @Published var status: String = ""
    @Published var needsPermission = false
    @Published var lastPDFFolder: URL?
    @Published var analysis: [UUID: Analysis] = [:]
    private var saved: [UUID: Data] = [:]
    private var bag = Set<AnyCancellable>()

    static let defaultLibrary = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/ETHNO-HRVATSKA")
    static let repoSource = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer/ETHNO-HRVATSKA")

    init(library override: URL? = nil) {
        if let o = override { library = o }
        else if let p = UserDefaults.standard.string(forKey: "library") { library = URL(fileURLWithPath: p) }
        else { library = Store.defaultLibrary }
        reload()
        $songs.debounce(for: .seconds(0.8), scheduler: DispatchQueue.main).sink { [weak self] _ in self?.saveAll() }.store(in: &bag)
    }

    var songsDir: URL { library.appendingPathComponent("songs") }
    var pdfDir: URL { library.appendingPathComponent("PDF") }
    var imagesDir: URL { library.appendingPathComponent("source/images") }

    func setLibrary(_ url: URL) {
        saveAll()
        library = url
        UserDefaults.standard.set(url.path, forKey: "library")
        reload()
    }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    func reload() {
        needsPermission = false
        status = ""
        songs = []; saved = [:]
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: songsDir.path) { try seedIfEmpty() }
            let files = try fm.contentsOfDirectory(atPath: songsDir.path).filter { $0.hasSuffix(".json") && $0.first?.isNumber == true }.sorted()
            if files.isEmpty { try seedIfEmpty() }
            let again = try fm.contentsOfDirectory(atPath: songsDir.path).filter { $0.hasSuffix(".json") && $0.first?.isNumber == true }.sorted()
            for f in again {
                let url = songsDir.appendingPathComponent(f)
                do {
                    let data = try Data(contentsOf: url)
                    var s = try JSONDecoder().decode(Song.self, from: data)
                    s.fileName = f
                    songs.append(s)
                    saved[s.id] = (try? Store.encoder().encode(s)) ?? data
                } catch { status = "Could not read \(f): \(error.localizedDescription)" }
            }
            selected = songs.first?.id
            if !status.hasPrefix("Could not read") { status = "\(songs.count) songs in \(library.path)" }
        } catch let e as NSError {
            if e.domain == NSCocoaErrorDomain && (e.code == 257 || e.code == 513) { needsPermission = true }
            status = "Cannot open the library \(library.path): \(e.localizedDescription)"
        }
    }

    /// First start in an empty folder: copy the five songs that travel inside the app.
    func seedIfEmpty() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: songsDir, withIntermediateDirectories: true)
        guard let seed = Bundle.main.resourceURL?.appendingPathComponent("seed"),
              let items = try? fm.contentsOfDirectory(atPath: seed.path) else { return }
        for f in items where f.hasSuffix(".json") {
            let dst = songsDir.appendingPathComponent(f)
            if !fm.fileExists(atPath: dst.path) { try fm.copyItem(at: seed.appendingPathComponent(f), to: dst) }
        }
    }

    func saveAll() {
        let fm = FileManager.default
        for i in songs.indices {
            var s = songs[i]
            if s.fileName == nil { s.fileName = "\(s.number)-\(s.slug).json"; songs[i].fileName = s.fileName }
            guard let data = try? Store.encoder().encode(s) else { continue }
            if saved[s.id] == data { continue }
            do {
                try fm.createDirectory(at: songsDir, withIntermediateDirectories: true)
                try data.write(to: songsDir.appendingPathComponent(s.fileName!), options: .atomic)
                saved[s.id] = data
            } catch { status = "Could not save \(s.title): \(error.localizedDescription)" }
        }
    }

    func index(of id: UUID?) -> Int? { songs.firstIndex(where: { $0.id == id }) }

    func newSong() {
        var s = Song()
        let used = songs.compactMap { Int($0.number) }
        s.number = String(format: "%02d", (used.max() ?? 0) + 1)
        s.slug = "new-song-\(s.number)"
        s.title = "New song"
        songs.append(s)
        selected = s.id
    }

    func deleteSong(_ id: UUID) {
        guard let i = index(of: id) else { return }
        if let f = songs[i].fileName { try? FileManager.default.trashItem(at: songsDir.appendingPathComponent(f), resultingItemURL: nil) }
        saved[id] = nil
        songs.remove(at: i)
        selected = songs.first?.id
    }

    // ------------------------------------------------------------ PDFs
    @discardableResult
    func makePDF(_ song: Song) -> URL? {
        do {
            let r = try Renderer.render(song)
            try FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true)
            let url = pdfDir.appendingPathComponent(song.pdfName)
            try r.data.write(to: url, options: .atomic)
            lastPDFFolder = pdfDir
            return url
        } catch {
            status = "\(song.title): \(error.localizedDescription)"
            return nil
        }
    }

    func makeAllPDFs() {
        var n = 0
        var bad: [String] = []
        for s in songs { if makePDF(s) != nil { n += 1 } else { bad.append(s.title) } }
        if bad.isEmpty { status = "Made \(n) PDFs in \(pdfDir.path)" }
        else { status = "Made \(n) PDFs; not made: \(bad.joined(separator: ", ")). \(status)" }
        lastPDFFolder = pdfDir
    }

    func reveal(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        else { NSWorkspace.shared.open(url.deletingLastPathComponent()) }
    }

    // ------------------------------------------------------------ files that belong to a song
    func imageURL(_ name: String) -> URL? {
        let fm = FileManager.default
        for base in [imagesDir, library, Store.repoSource.appendingPathComponent("source/images"), Store.repoSource.appendingPathComponent("source")] {
            let u = base.appendingPathComponent(name)
            if fm.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    func audioURL(_ name: String) -> URL? {
        let fm = FileManager.default
        if name.hasPrefix("/"), fm.fileExists(atPath: name) { return URL(fileURLWithPath: name) }
        for base in [library, library.appendingPathComponent("recordings")] {
            let u = base.appendingPathComponent(name)
            if fm.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    static let imageExts: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "pdf", "webp"]
    static let audioExts: Set<String> = ["m4a", "mp3", "wav", "aif", "aiff", "caf", "aac", "flac"]

    /// Files dropped on the window: images and a recording go into the library and are linked to the open song; .txt is returned as text.
    func importFiles(_ urls: [URL], into id: UUID?) -> String? {
        guard let i = index(of: id) else { status = "Open or create a song first, then drop the files."; return nil }
        let fm = FileManager.default
        var text: String? = nil
        var notes: [String] = []
        for u in urls {
            let ext = u.pathExtension.lowercased()
            do {
                if Store.imageExts.contains(ext) {
                    try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
                    let dst = imagesDir.appendingPathComponent(u.lastPathComponent)
                    if !fm.fileExists(atPath: dst.path) { try fm.copyItem(at: u, to: dst) }
                    if !songs[i].sources.images.contains(u.lastPathComponent) { songs[i].sources.images.append(u.lastPathComponent) }
                    notes.append("image \(u.lastPathComponent)")
                } else if Store.audioExts.contains(ext) {
                    let dst = library.appendingPathComponent(u.lastPathComponent)
                    if !fm.fileExists(atPath: dst.path) { try fm.copyItem(at: u, to: dst) }
                    songs[i].sources.audio = u.lastPathComponent
                    notes.append("recording \(u.lastPathComponent)")
                } else if ["txt", "md", "cho"].contains(ext), let t = try? String(contentsOf: u, encoding: .utf8) {
                    text = (text.map { $0 + "\n\n" } ?? "") + t
                    notes.append("text \(u.lastPathComponent)")
                } else { notes.append("skipped \(u.lastPathComponent) (not an image, recording or text)") }
            } catch { notes.append("could not copy \(u.lastPathComponent): \(error.localizedDescription)") }
        }
        status = "Added: " + notes.joined(separator: "; ")
        return text
    }
}

/// Result of the optional Analyse button (the repo's analysis tools). Everything here is a suggestion, never certain.
struct Analysis {
    var tempo: Double?
    var keys: [String] = []
    var chords: [String] = []      // most frequent first
    var summary: String = ""
}
