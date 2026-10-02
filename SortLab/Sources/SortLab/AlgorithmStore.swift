import Foundation

/// One algorithm = one .js file in ~/Library/Application Support/SortLab/algorithms/.
struct AlgoFile: Identifiable, Equatable {
    let id: String        // file name, e.g. "003 Comb Sort.js"
    var name: String      // taken from register("…") in the source
    var source: String
}

enum AlgorithmStore {
    static let root: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SortLab", isDirectory: true)
    }()
    static var dir: URL { root.appendingPathComponent("algorithms", isDirectory: true) }

    static let template = """
    register("%@", s => {
      // s.n, s.get(i), s.set(i, v), s.swap(i, j), s.less(i, j), s.greater(i, j),
      // s.lessV(i, v), s.greaterV(i, v), s.copy()
      for (let i = 0; i < s.n - 1; i++) {
        for (let j = 0; j < s.n - 1 - i; j++) {
          if (s.less(j + 1, j)) s.swap(j, j + 1);
        }
      }
    });

    """

    private static let nameRegex = try! NSRegularExpression(pattern: #"register\(\s*(["'])(.*?)\1"#)

    static func nameRange(in source: String) -> NSRange? {
        let ns = source as NSString
        guard let m = nameRegex.firstMatch(in: source, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return m.range(at: 2)
    }

    static func parseName(_ source: String) -> String? {
        nameRange(in: source).map { (source as NSString).substring(with: $0) }
    }

    static func bundledSource() -> String {
        Bundle.main.url(forResource: "algorithms", withExtension: "js")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    /// Splits a script containing several top-level register(...) blocks into one source per algorithm.
    static func split(_ source: String) -> [String] {
        var chunks: [[Substring]] = []
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("register(") { chunks.append([line]) }
            else if !chunks.isEmpty { chunks[chunks.count - 1].append(line) }
        }
        return chunks.map { lines in
            var text = lines.joined(separator: "\n")
            if let r = text.range(of: "\n});", options: .backwards) { text = String(text[..<r.upperBound]) }
            return text + "\n"
        }
    }

    // MARK: Files

    private static func jsFiles() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
            .filter { $0.hasSuffix(".js") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Creates the folder and seeds it on first run (from the old single algorithms.js if present, else the built-ins).
    static func prepare() {
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        guard jsFiles().isEmpty else { return }
        var source = bundledSource()
        let old = root.appendingPathComponent("algorithms.js")
        if let s = try? String(contentsOf: old, encoding: .utf8), !split(s).isEmpty {
            source = s
            try? fm.moveItem(at: old, to: root.appendingPathComponent("algorithms.js.migrated"))
        }
        for chunk in split(source) { _ = create(chunk) }
    }

    static func load() -> [AlgoFile] {
        jsFiles().compactMap { file in
            guard let src = try? String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8) else { return nil }
            return AlgoFile(id: file, name: parseName(src) ?? (file as NSString).deletingPathExtension, source: src)
        }
    }

    static func write(_ source: String, id: String) {
        try? source.write(to: dir.appendingPathComponent(id), atomically: true, encoding: .utf8)
    }

    static func delete(id: String) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(id))
    }

    /// Writes a new algorithm file at the end of the list and returns its id.
    static func create(_ source: String) -> String {
        let next = (jsFiles().compactMap { Int($0.prefix(while: \.isNumber)) }.max() ?? 0) + 1
        let name = parseName(source) ?? "algorithm"
        let safe = String(name.filter { $0.isLetter || $0.isNumber || " -()".contains($0) }.prefix(40))
            .trimmingCharacters(in: .whitespaces)
        let id = String(format: "%03d %@.js", next, safe.isEmpty ? "algorithm" : safe)
        write(source, id: id)
        return id
    }

    /// Re-adds built-in algorithms that are no longer present (matched by name). Returns how many were added.
    static func restoreBuiltins() -> Int {
        let have = Set(load().map(\.name))
        var added = 0
        for chunk in split(bundledSource()) where !have.contains(parseName(chunk) ?? "") {
            _ = create(chunk); added += 1
        }
        return added
    }
}
