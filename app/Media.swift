import AppKit
import AVFoundation
import Vision

// ---------------------------------------------------------------- audio player with a loop
final class Player: NSObject, ObservableObject {
    @Published var url: URL?
    @Published var time: Double = 0
    @Published var duration: Double = 0
    @Published var playing = false
    @Published var loopOn = false
    @Published var loopA: Double?
    @Published var loopB: Double?
    @Published var error: String?
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(_ u: URL?) {
        stop()
        player = nil; url = u; time = 0; duration = 0; loopA = nil; loopB = nil; loopOn = false; error = nil
        guard let u = u else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: u)
            p.prepareToPlay(); player = p; duration = p.duration
        } catch { self.error = "Cannot play \(u.lastPathComponent): \(error.localizedDescription)" }
    }

    func toggle() {
        guard let p = player else { return }
        if p.isPlaying { stop() }
        else {
            if let a = loopA, loopOn, p.currentTime < a { p.currentTime = a }
            p.play(); playing = true
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in self?.tick() }
        }
    }

    func stop() {
        player?.pause(); playing = false
        timer?.invalidate(); timer = nil
        if let p = player { time = p.currentTime }
    }

    func seek(_ t: Double) { player?.currentTime = max(0, min(t, duration)); time = player?.currentTime ?? 0 }

    func setA() { loopA = time; if let b = loopB, b <= time { loopB = nil } }
    func setB() { loopB = time; if let a = loopA, a >= time { loopA = nil } }
    func clearLoop() { loopA = nil; loopB = nil; loopOn = false }

    private func tick() {
        guard let p = player else { return }
        if loopOn, let a = loopA, let b = loopB, b > a, p.currentTime >= b { p.currentTime = a }
        time = p.currentTime
        if !p.isPlaying { playing = false; timer?.invalidate(); timer = nil }
    }
}

// ---------------------------------------------------------------- OCR (Vision)
enum OCR {
    /// Lines of text found in an image, top to bottom. Meant as a first draft to correct against the picture.
    static func lines(in url: URL) throws -> [String] {
        if url.pathExtension.lowercased() == "pdf" { throw RenderError.msg("OCR reads pictures; this is a PDF. Open it in Preview and drop a picture of the page.") }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false      // do not "correct" Croatian words into English ones
        if #available(macOS 13.0, *) { req.automaticallyDetectsLanguage = true }
        try VNImageRequestHandler(url: url, options: [:]).perform([req])
        let obs = (req.results ?? []).sorted {
            let a = $0.boundingBox, b = $1.boundingBox
            if abs(a.midY - b.midY) > 0.012 { return a.midY > b.midY }
            return a.minX < b.minX
        }
        return obs.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

// ---------------------------------------------------------------- Analyse (the repo's tools, only when installed)
final class Analyser {
    static let envPATH = [NSHomeDirectory() + "/.pyenv/shims", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"].joined(separator: ":")
    var process: Process?
    var cancelled = false

    static func scriptDir(library: URL) -> URL? {
        for d in [library.appendingPathComponent("tools/analysis"), Store.repoSource.appendingPathComponent("tools/analysis")] {
            if FileManager.default.fileExists(atPath: d.appendingPathComponent("analyze.py").path) { return d }
        }
        return nil
    }

    @discardableResult
    func run(_ args: [String], timeout: TimeInterval = 3600) -> (Int32, String) {
        let p = Process(), out = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env"); p.arguments = args
        var env = ProcessInfo.processInfo.environment; env["PATH"] = Analyser.envPATH; env["PYTHONWARNINGS"] = "ignore"
        p.environment = env; p.standardOutput = out; p.standardError = out
        process = p
        do { try p.run() } catch { return (127, "\(error)") }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// Says plainly what is missing; nil when everything is there.
    func missing(library: URL) -> String? {
        var lack: [String] = []
        if Analyser.scriptDir(library: library) == nil { lack.append("the ETHNO-HRVATSKA repository with tools/analysis/analyze.py (expected in ~/Developer/ETHNO-HRVATSKA or in the library's tools folder)") }
        if run(["python3", "--version"]).0 != 0 { lack.append("python3") }
        else if run(["python3", "-c", "import librosa, numpy, pretty_midi"]).0 != 0 { lack.append("the Python packages librosa, numpy and pretty_midi (pip install -r tools/requirements.txt)") }
        if run(["which", "demucs"]).0 != 0 { lack.append("demucs (pip install demucs)") }
        return lack.isEmpty ? nil : "Analyse cannot run here. Missing: " + lack.joined(separator: "; ") + "."
    }

    func analyse(audio: URL, library: URL, progress: @escaping (String) -> Void) -> Result<Analysis, RenderError> {
        if let m = missing(library: library) { return .failure(.msg(m)) }
        guard let dir = Analyser.scriptDir(library: library) else { return .failure(.msg("analysis scripts not found")) }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ethno-analysis-\(UUID().uuidString.prefix(8))")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        DispatchQueue.main.async { progress("Separating the instruments with demucs (this takes minutes)...") }
        let (c1, o1) = run(["demucs", "-n", "htdemucs", "-o", tmp.path, audio.path])
        if cancelled { return .failure(.msg("Analyse stopped.")) }
        let base = audio.deletingPathExtension().lastPathComponent
        let stems = tmp.appendingPathComponent("htdemucs/\(base)")
        guard c1 == 0, FileManager.default.fileExists(atPath: stems.appendingPathComponent("other.wav").path) else {
            return .failure(.msg("demucs failed: " + String(o1.suffix(300))))
        }
        DispatchQueue.main.async { progress("Looking for chords and tempo...") }
        let outJSON = tmp.appendingPathComponent("analysis.json")
        let (c2, o2) = run(["python3", dir.appendingPathComponent("analyze.py").path, audio.path, stems.path, outJSON.path])
        guard c2 == 0, let data = try? Data(contentsOf: outJSON), let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.msg("analyze.py failed: " + String(o2.suffix(300))))
        }
        var a = Analysis()
        a.tempo = j["tempo_bpm"] as? Double
        if let ks = j["key_candidates"] as? [[Any]] { a.keys = ks.compactMap { $0.count > 1 ? ($0[1] as? String) : nil } }
        if let h = j["chord_beats_histogram"] as? [String: Double] { a.chords = h.sorted { $0.value > $1.value }.map { $0.key } }
        else if let h = j["chord_beats_histogram"] as? [String: Int] { a.chords = h.sorted { $0.value > $1.value }.map { $0.key } }
        a.summary = "Suggestions from the recording, not certain: tempo about \(a.tempo.map { String(Int($0)) } ?? "?") BPM; key candidates \(a.keys.prefix(3).joined(separator: ", ")); chords by time heard: \(a.chords.prefix(8).joined(separator: " "))."
        let keep = library.appendingPathComponent("analysis")
        try? FileManager.default.createDirectory(at: keep, withIntermediateDirectories: true)
        try? data.write(to: keep.appendingPathComponent("\(base).analysis.json"))
        return .success(a)
    }
}
