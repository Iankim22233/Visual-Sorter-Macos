import SwiftUI
import AppKit

enum VisualStyle: String, CaseIterable, Identifiable {
    case bars = "Bars", dots = "Dots", line = "Line", pie = "Pie"
    var id: String { rawValue }
}

@MainActor
final class SortModel: ObservableObject {
    // Observed by the UI. `values` is mutated on every op, so views refresh via `frame`.
    @Published private(set) var frame = 0
    @Published var algorithm = "Quick Sort"
    @Published private(set) var algorithmNames: [String] = []
    @Published private(set) var message = ""
    @Published private(set) var files: [AlgoFile] = []
    @Published private(set) var fileErrors: [String: String] = [:]
    @Published var editingID: String?
    @Published var justCreatedID: String?
    @Published var manual = false {
        didSet { if manual { stop() } else { cancelDrag() } }
    }
    @Published private(set) var moves = 0
    @Published var count = 100
    @Published var speedT = 0.55            // 0...1, log-mapped to ops/second
    @Published var volume = 0.5 { didSet { synth.volume = Float(volume) } }
    @Published var muted = false { didSet { synth.muted = muted } }
    @Published var rainbow = true
    @Published var style: VisualStyle = .bars
    @Published private(set) var isRunning = false

    private(set) var values: [Int] = []     // permutation of 1...count
    /// What the view draws: the live preview while dragging in manual mode, otherwise `values`.
    var displayValues: [Int] { preview ?? values }
    private(set) var markA = -1
    private(set) var markB = -1
    private(set) var sortedCount = 0
    private(set) var comparisons = 0
    private(set) var writes = 0

    private let synth = Synth()
    private let engine = ScriptEngine()
    private var task: Task<Void, Never>?
    private var runID = 0
    private var speedOverride: Double?
    private var opsSinceTick = 0
    private var dragFrom: Int?
    private var dragTo: Int?
    private var preview: [Int]?

    init() {
        synth.volume = Float(volume)
        values = Array(1...count)
        AlgorithmStore.prepare()
        reloadAlgorithms()
    }

    // MARK: Algorithm files

    func reloadAlgorithms() {
        files = AlgorithmStore.load()
        fileErrors = [:]
        var good = files
        if let _ = engine.load(files.map(\.source).joined(separator: "\n")) {
            // At least one file is broken: keep the working ones and flag the others.
            good = files.filter { f in
                if let e = ScriptEngine.check(f.source) { fileErrors[f.id] = e; return false }
                return true
            }
            if !good.isEmpty { _ = engine.load(good.map(\.source).joined(separator: "\n")) }
        }
        algorithmNames = good.isEmpty ? [] : engine.names
        if !algorithmNames.contains(algorithm), let first = algorithmNames.first { algorithm = first }
        if editingID == nil || !files.contains(where: { $0.id == editingID }) {
            editingID = files.first(where: { $0.name == algorithm })?.id ?? files.first?.id
        }
    }

    func selectAlgorithm(_ name: String) {
        guard !isRunning else { return }
        algorithm = name
        if let f = files.first(where: { $0.name == name }) { editingID = f.id }
    }

    /// Validates and saves one algorithm's source, then reloads everything. Returns an error message, or nil.
    func saveAlgorithm(id: String, source: String) -> String? {
        if isRunning { return "Stop the current run first, then save again." }
        if let e = ScriptEngine.check(source) { return e }
        let oldName = files.first(where: { $0.id == id })?.name
        AlgorithmStore.write(source, id: id)
        reloadAlgorithms()
        if algorithm == oldName, let n = files.first(where: { $0.id == id })?.name { algorithm = n }
        return nil
    }

    /// Creates a new algorithm from the template and starts editing it.
    func newAlgorithm() {
        guard !isRunning else { return }
        let taken = Set(files.map(\.name))
        var n = 1
        while taken.contains("My Sort \(n)") { n += 1 }
        let name = "My Sort \(n)"
        let id = AlgorithmStore.create(String(format: AlgorithmStore.template, name))
        reloadAlgorithms()
        algorithm = name
        editingID = id
        justCreatedID = id
    }

    func deleteAlgorithm(id: String) {
        guard !isRunning, files.count > 1 else { return }
        AlgorithmStore.delete(id: id)
        editingID = nil
        reloadAlgorithms()
    }

    @discardableResult
    func restoreBuiltins() -> Int {
        let n = AlgorithmStore.restoreBuiltins()
        reloadAlgorithms()
        return n
    }

    // MARK: Manual sort (drag a line and drop it somewhere else)

    func dragBegan(at i: Int) {
        guard manual, !isRunning, dragFrom == nil, values.indices.contains(i) else { return }
        dragFrom = i; dragTo = i
        preview = values
        sortedCount = 0
        markA = i; markB = -1
        beep(values[i])
        frame += 1
    }

    func dragMoved(to i: Int) {
        guard let from = dragFrom, i != dragTo, values.indices.contains(i) else { return }
        dragTo = i
        var p = values
        let v = p.remove(at: from)
        p.insert(v, at: i)
        preview = p
        markA = i
        beep(v)
        frame += 1
    }

    func dragEnded() {
        guard let from = dragFrom else { return }
        if let p = preview, let to = dragTo, to != from {
            values = p
            moves += 1
            beep(p[to])
        }
        clearDrag()
        if moves > 0, values == Array(1...count) {
            message = "Sorted by hand in \(moves) moves!"
            launch { _ in true }
        }
    }

    private func cancelDrag() { clearDrag() }

    private func clearDrag() {
        dragFrom = nil; dragTo = nil; preview = nil
        markA = -1; markB = -1
        frame += 1
    }

    private func beep(_ v: Int) {
        synth.play(fraction: min(max(Double(v) / Double(count), 0), 1), duration: 0.07)
    }

    var speed: Double { 5 * pow(2000, speedT) }   // 5 ... 10,000 ops/s

    // MARK: Controls

    func setCount(_ n: Int) {
        guard n != count else { return }
        stop()
        count = n
        reset()
    }

    func reset() {
        stop()
        clearDrag()
        values = Array(1...count)
        sortedCount = 0; markA = -1; markB = -1; comparisons = 0; writes = 0; moves = 0; message = ""
        frame += 1
    }

    func stop() {
        engine.cancel()
        task?.cancel()
        task = nil
        runID += 1
        isRunning = false
        markA = -1; markB = -1
        frame += 1
    }

    func scramble() {
        launch { s in
            s.speedOverride = max(Double(s.count) * 1.2, 60)
            defer { s.speedOverride = nil }
            for i in stride(from: s.count - 1, to: 0, by: -1) {
                try await s.swap(i, Int.random(in: 0...i))
            }
            return false
        }
        comparisons = 0; writes = 0; moves = 0; message = ""
    }

    func sort() {
        guard !isRunning else { return }
        guard let index = algorithmNames.firstIndex(of: algorithm) else { return }
        let snapshot = values
        launch { s in
            s.message = "Running \(s.algorithm)…"
            let result = await s.engine.run(index: index, values: snapshot)
            try Task.checkCancellation()
            if let err = result.error { s.message = "Error: \(err)" }
            else if result.hitLimit { s.message = "Stopped at the \(ScriptEngine.stepLimit.formatted()) step limit" }
            else { s.message = "" }
            s.comparisons = 0; s.writes = 0
            try await s.replay(result.ops)
            return result.completed
        }
        comparisons = 0; writes = 0
    }

    /// Plays back recorded steps. `work` returns true if the green finish sweep should follow.
    private func launch(_ work: @escaping (SortModel) async throws -> Bool) {
        guard !isRunning else { return }
        isRunning = true
        sortedCount = 0
        runID += 1
        let id = runID
        task = Task {
            do {
                if try await work(self) { try await finishSweep() }
            } catch {}
            if runID == id {
                isRunning = false; markA = -1; markB = -1; frame += 1
            }
        }
    }

    private func replay(_ ops: [Int32]) async throws {
        var k = 0
        while k + 3 < ops.count {
            let t = ops[k], i = Int(ops[k + 1]), j = Int(ops[k + 2]), v = Int(ops[k + 3])
            k += 4
            switch t {
            case 1: comparisons += 1; try await tick(i, j, v)
            case 2: writes += 1; values[i] = v; try await tick(i, -1, v)
            case 3: writes += 2; values.swapAt(i, j); try await tick(i, j, v)
            default: try await tick(i, -1, v)
            }
        }
    }

    private func finishSweep() async throws {
        markA = -1; markB = -1
        let delay = max(0.002, min(0.03, 1.2 / Double(count)))
        for i in 0..<count {
            sortedCount = i + 1
            synth.play(fraction: Double(values[i]) / Double(count), duration: 0.05)
            frame += 1
            try await Task.sleep(for: .seconds(delay))
        }
    }

    // MARK: Operations

    func swap(_ i: Int, _ j: Int) async throws {
        guard i != j else { return }
        writes += 2
        values.swapAt(i, j)
        try await tick(i, j, values[i])
    }

    /// Pacing: `speed` ops/second. Above 60 ops/s several ops share one frame and one blip.
    private func tick(_ a: Int, _ b: Int, _ v: Int) async throws {
        try Task.checkCancellation()
        markA = a; markB = b
        opsSinceTick += 1
        let sp = speedOverride ?? speed
        let perFrame = max(1.0, sp / 60)
        guard Double(opsSinceTick) >= perFrame else { return }
        opsSinceTick = 0
        frame += 1
        synth.play(fraction: min(max(Double(v) / Double(count), 0), 1), duration: 0.06)
        try await Task.sleep(for: .seconds(perFrame / sp))
    }
}
