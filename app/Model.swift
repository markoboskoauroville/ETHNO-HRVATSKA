import Foundation

// Song JSON, schema ethno-song/1 (songs/SCHEMA.md). Every field round-trips, so editing a song never loses data.

/// Any JSON value, kept untouched so fields this app does not edit yet (rhythm object, melody) survive a save.
enum JSONValue: Codable, Equatable {
    case null, bool(Bool), num(Double), str(String), arr([JSONValue]), obj([String: JSONValue])
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .num(n) }
        else if let s = try? c.decode(String.self) { self = .str(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .arr(a) }
        else { self = .obj(try c.decode([String: JSONValue].self)) }
    }
    func encode(to e: Encoder) throws {
        var c = e.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .num(let n): if n == n.rounded() && abs(n) < 1e15 { try c.encode(Int(n)) } else { try c.encode(n) }
        case .str(let s): try c.encode(s)
        case .arr(let a): try c.encode(a)
        case .obj(let o): try c.encode(o)
        }
    }
}

struct ChordMark: Codable, Equatable, Identifiable {
    var id = UUID()
    var at_char: Int
    var chord: String
    var source: String = "manual"
    var confirmed: Bool = true
    enum CodingKeys: String, CodingKey { case at_char, chord, source, confirmed }
    init(at_char: Int, chord: String, source: String = "manual", confirmed: Bool = true) {
        self.at_char = at_char; self.chord = chord; self.source = source; self.confirmed = confirmed
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        at_char = try c.decodeIfPresent(Int.self, forKey: .at_char) ?? 0
        chord = try c.decodeIfPresent(String.self, forKey: .chord) ?? ""
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "manual"
        confirmed = try c.decodeIfPresent(Bool.self, forKey: .confirmed) ?? true
    }
}

struct SongLine: Codable, Equatable, Identifiable {
    var id = UUID()
    var text: String = ""
    var translation: String = ""
    var repeatMark: String? = nil
    var chords: [ChordMark] = []
    enum CodingKeys: String, CodingKey { case text, translation, repeatMark = "repeat", chords }
    init() {}
    init(text: String) { self.text = text }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        translation = try c.decodeIfPresent(String.self, forKey: .translation) ?? ""
        repeatMark = try c.decodeIfPresent(String.self, forKey: .repeatMark)
        chords = try c.decodeIfPresent([ChordMark].self, forKey: .chords) ?? []
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(text, forKey: .text)
        try c.encode(translation, forKey: .translation)
        try c.encode(repeatMark, forKey: .repeatMark)      // null when none, as in the Python JSON
        try c.encode(chords, forKey: .chords)
    }
}

struct SongSection: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var lines: [SongLine] = []
    enum CodingKeys: String, CodingKey { case name, lines }
    init(name: String = "", lines: [SongLine] = []) { self.name = name; self.lines = lines }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        lines = try c.decodeIfPresent([SongLine].self, forKey: .lines) ?? []
    }
}

struct PlayRow: Codable, Equatable, Identifiable {
    var id = UUID()
    var label: String = ""
    var chords: String = ""
    enum CodingKeys: String, CodingKey { case label, chords }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        chords = try c.decodeIfPresent(String.self, forKey: .chords) ?? ""
    }
}

struct SongSources: Codable, Equatable {
    var lyrics: String? = nil
    var images: [String] = []
    var audio: String? = nil
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        lyrics = try c.decodeIfPresent(String.self, forKey: .lyrics)
        images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        audio = try c.decodeIfPresent(String.self, forKey: .audio)
    }
}

struct Song: Codable, Equatable, Identifiable {
    var id = UUID()
    var schema = "ethno-song/1"
    var number = "00"
    var slug = "new-song"
    var title = "New song"
    var subtitle = ""
    var language = ""
    var key = ""
    var tempo = ""
    var rhythm = ""
    var rhythmObj: Rhythm? = nil
    var melody: Melody? = nil
    var scale: String? = nil
    var confidence = ""
    var chord_source = "audio"
    var play: [PlayRow] = []
    var sections: [SongSection] = [SongSection(name: "1", lines: [SongLine()])]
    var arrangement: [String] = []
    var notes: [String] = []
    var evidence: [String] = []
    var uncertain: [String] = []
    var sources = SongSources()
    var fileName: String? = nil       // not stored in the JSON

    enum CodingKeys: String, CodingKey {
        case schema, number, slug, title, subtitle, language, key, tempo, rhythm, melody, scale, confidence, chord_source
        case play, sections, arrangement, notes, evidence, uncertain, sources
    }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys) throws -> String { try c.decodeIfPresent(String.self, forKey: k) ?? "" }
        schema = try c.decodeIfPresent(String.self, forKey: .schema) ?? "ethno-song/1"
        number = try s(.number); slug = try s(.slug); title = try s(.title); subtitle = try s(.subtitle)
        language = try s(.language); key = try s(.key); tempo = try s(.tempo)
        if let r = (try? c.decodeIfPresent(String.self, forKey: .rhythm)) ?? nil { rhythm = r }
        else if let o = (try? c.decodeIfPresent(Rhythm.self, forKey: .rhythm)) ?? nil { rhythmObj = o; rhythm = o.name }
        melody = (try? c.decodeIfPresent(Melody.self, forKey: .melody)) ?? nil
        scale = try c.decodeIfPresent(String.self, forKey: .scale)
        confidence = try s(.confidence)
        chord_source = try c.decodeIfPresent(String.self, forKey: .chord_source) ?? "audio"
        play = try c.decodeIfPresent([PlayRow].self, forKey: .play) ?? []
        sections = try c.decodeIfPresent([SongSection].self, forKey: .sections) ?? []
        arrangement = try c.decodeIfPresent([String].self, forKey: .arrangement) ?? []
        notes = try c.decodeIfPresent([String].self, forKey: .notes) ?? []
        evidence = try c.decodeIfPresent([String].self, forKey: .evidence) ?? []
        uncertain = try c.decodeIfPresent([String].self, forKey: .uncertain) ?? []
        sources = try c.decodeIfPresent(SongSources.self, forKey: .sources) ?? SongSources()
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(schema, forKey: .schema); try c.encode(number, forKey: .number); try c.encode(slug, forKey: .slug)
        try c.encode(title, forKey: .title); try c.encode(subtitle, forKey: .subtitle); try c.encode(language, forKey: .language)
        try c.encode(key, forKey: .key); try c.encode(tempo, forKey: .tempo); if let o = rhythmObj { try c.encode(o, forKey: .rhythm) } else { try c.encode(rhythm, forKey: .rhythm) }
        try c.encodeIfPresent(melody, forKey: .melody)
        try c.encodeIfPresent(scale, forKey: .scale)
        try c.encode(confidence, forKey: .confidence); try c.encode(chord_source, forKey: .chord_source)
        try c.encode(play, forKey: .play); try c.encode(sections, forKey: .sections)
        try c.encode(arrangement, forKey: .arrangement); try c.encode(notes, forKey: .notes)
        try c.encode(evidence, forKey: .evidence); try c.encode(uncertain, forKey: .uncertain)
        try c.encode(sources, forKey: .sources)
    }

    static func asciiSlug(_ t: String) -> String {
        let f = t.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        var out = "", dash = false
        for ch in f.unicodeScalars {
            if (ch.value >= 97 && ch.value <= 122) || (ch.value >= 48 && ch.value <= 57) { out.unicodeScalars.append(ch); dash = false }
            else if !dash && !out.isEmpty { out += "-"; dash = true }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-")).isEmpty ? "song" : out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Rhythm as the info line prints it: name, meter unless in the name, (grouping). SCHEMA.md section 3.
    var rhythmText: String {
        guard let r = rhythmObj else { return rhythm }
        var t = r.name
        if !r.meter.isEmpty && !r.name.contains(r.meter) { t += " " + r.meter }
        if !r.grouping.isEmpty { t += " (\(r.grouping))" }
        return t
    }

    var pdfName: String {
        let safe = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return "\(number) \(safe).pdf"
    }
}

/// Text from the "paste" box: a blank line starts a new section, every other line is a lyric line.
func sectionsFromText(_ text: String) -> [SongSection] {
    var out: [SongSection] = [], cur: [SongLine] = []
    func flush() { if !cur.isEmpty { out.append(SongSection(name: String(out.count + 1), lines: cur)); cur = [] } }
    for raw in text.components(separatedBy: .newlines) {
        let t = raw.trimmingCharacters(in: .whitespaces).precomposedStringWithCanonicalMapping
        if t.isEmpty { flush() } else { cur.append(SongLine(text: t)) }
    }
    flush()
    return out
}
