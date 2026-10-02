import Foundation
import JavaScriptCore

/// Records the steps a JS algorithm takes. Each step is 4 Int32s: type, i, j, value.
/// type: 0 read, 1 compare, 2 set, 3 swap.
final class OpRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var ops: [Int32] = []
    private var cancelled = false
    private var limit = 0
    private var n = 0
    private(set) var hitLimit = false
    private(set) var error: String?

    func reset(limit: Int, n: Int) {
        lock.lock(); defer { lock.unlock() }
        ops = []; ops.reserveCapacity(1 << 16)
        cancelled = false; hitLimit = false; error = nil
        self.limit = limit; self.n = n
    }

    func cancel() { lock.lock(); cancelled = true; lock.unlock() }

    func take() -> [Int32] { lock.lock(); defer { lock.unlock() }; return ops }

    /// Returns false to make the script stop (cancelled, over the cap, or a bad index).
    func record(_ t: Int32, _ i: Int32, _ j: Int32, _ v: Int32) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if cancelled { return false }
        if ops.count >= limit * 4 { hitLimit = true; return false }
        let needsJ = t == 1 || t == 3
        if i < 0 || Int(i) >= n || (needsJ ? (j < 0 || Int(j) >= n) : false) {
            error = "Index out of range (\(i)\(needsJ ? ", \(j)" : "")) with \(n) lines"
            return false
        }
        ops.append(t); ops.append(i); ops.append(j); ops.append(v)
        return true
    }
}

struct ScriptResult {
    var ops: [Int32]
    var completed: Bool
    var hitLimit: Bool
    var error: String?
}

final class ScriptEngine: @unchecked Sendable {
    static let stepLimit = 3_000_000

    private let recorder = OpRecorder()
    private let queue = DispatchQueue(label: "sortlab.script", qos: .userInitiated)
    private var context: JSContext?
    private var lastError: String?
    private(set) var names: [String] = []

    private static let prelude = """
    const __algos = [];
    function register(name, fn) { __algos.push({ name, fn }); }
    function __op(t, i, j, v) { if (!__rec(t, i, j, v)) throw "__stop"; }
    function __run(idx, input) {
      const a = input.slice();
      const s = {
        n: a.length,
        get(i) { __op(0, i, -1, a[i]); return a[i]; },
        set(i, v) { a[i] = v; __op(2, i, -1, v); },
        swap(i, j) { if (i === j) return; const t = a[i]; a[i] = a[j]; a[j] = t; __op(3, i, j, a[i]); },
        less(i, j) { __op(1, i, j, a[i]); return a[i] < a[j]; },
        greater(i, j) { __op(1, i, j, a[i]); return a[i] > a[j]; },
        lessV(i, v) { __op(1, i, i, a[i]); return a[i] < v; },
        greaterV(i, v) { __op(1, i, i, a[i]); return a[i] > v; },
        copy() { return a.slice(); },
      };
      __algos[idx].fn(s);
    }
    """

    /// Loads a script; on success replaces the current algorithms. Returns an error message on failure.
    func load(_ source: String) -> String? {
        guard let ctx = JSContext() else { return "Could not create JavaScript context" }
        var firstError: String?
        ctx.exceptionHandler = { _, e in
            guard firstError == nil, let e else { return }
            let line = e.objectForKeyedSubscript("line")?.toInt32() ?? 0
            firstError = "\(e.toString() ?? "script error")" + (line > 0 ? " (line \(line - 0))" : "")
        }
        let rec: @convention(block) (Int32, Int32, Int32, Int32) -> Bool = { [recorder] t, i, j, v in
            recorder.record(t, i, j, v)
        }
        ctx.setObject(rec, forKeyedSubscript: "__rec" as NSString)
        ctx.evaluateScript(Self.prelude)
        ctx.evaluateScript(source, withSourceURL: URL(string: "algorithms.js"))
        if let firstError { return firstError }
        guard let list = ctx.evaluateScript("__algos.map(a => a.name)")?.toArray() as? [String], !list.isEmpty else {
            return "No algorithms registered. Use register(\"Name\", s => { ... })"
        }
        ctx.exceptionHandler = { [weak self] _, e in
            guard let self, let e else { return }
            let line = e.objectForKeyedSubscript("line")?.toInt32() ?? 0
            self.lastError = (e.toString() ?? "script error") + (line > 0 ? " (line \(line))" : "")
        }
        queue.sync { context = ctx; names = list }
        return nil
    }

    func cancel() { recorder.cancel() }

    func run(index: Int, values: [Int]) async -> ScriptResult {
        await withCheckedContinuation { cont in
            queue.async { cont.resume(returning: self.runSync(index, values)) }
        }
    }

    private func runSync(_ index: Int, _ values: [Int]) -> ScriptResult {
        guard let ctx = context else {
            return ScriptResult(ops: [], completed: false, hitLimit: false, error: "No script loaded")
        }
        recorder.reset(limit: Self.stepLimit, n: values.count)
        lastError = nil
        ctx.objectForKeyedSubscript("__run").call(withArguments: [index, values])
        var error: String?
        if let e = recorder.error { error = e }
        else if let e = lastError, e != "__stop" { error = e }
        let stopped = lastError != nil
        return ScriptResult(ops: recorder.take(), completed: !stopped, hitLimit: recorder.hitLimit, error: error)
    }
}

extension ScriptEngine {
    /// Validates one script in a throwaway context. Returns an error message, or nil if it loads and registers something.
    static func check(_ source: String) -> String? { ScriptEngine().load(source) }
}
