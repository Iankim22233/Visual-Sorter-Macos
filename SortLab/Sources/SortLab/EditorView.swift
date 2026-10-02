import SwiftUI
import AppKit

struct EditorView: View {
    @ObservedObject var model: SortModel
    @State private var drafts: [String: String] = [:]   // unsaved text per file id
    @State private var saveError: String?
    @State private var confirmDelete = false

    private var current: AlgoFile? { model.files.first { $0.id == model.editingID } }

    private var textBinding: Binding<String> {
        Binding(
            get: { drafts[model.editingID ?? ""] ?? current?.source ?? "" },
            set: { new in
                guard let c = current else { return }
                drafts[c.id] = new == c.source ? nil : new
                if model.justCreatedID != nil { model.justCreatedID = nil }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            AlgorithmTabs(
                items: model.files.map {
                    TabItem(id: $0.id, title: $0.name, modified: drafts[$0.id] != nil, error: model.fileErrors[$0.id] != nil)
                },
                selection: model.editingID,
                onSelect: { model.editingID = $0; saveError = nil },
                onNew: { model.newAlgorithm(); saveError = nil }
            )
            Divider()
            HStack(spacing: 10) {
                Button("Revert") { if let c = current { drafts[c.id] = nil; saveError = nil } }
                    .disabled(current.map { drafts[$0.id] == nil } ?? true)
                Button("Delete", role: .destructive) { confirmDelete = true }
                    .disabled(model.files.count < 2)
                Menu("More") {
                    Button("Restore Missing Built-in Algorithms") {
                        let n = model.restoreBuiltins()
                        saveError = nil
                        if n == 0 { NSSound.beep() }
                    }
                    Button("Show Files in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([AlgorithmStore.dir])
                    }
                }
                .fixedSize()
                Spacer()
                Button("Save & Apply") { save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(current == nil)
            }
            .padding(10)
            Text("s.n · s.get(i) · s.set(i, v) · s.swap(i, j) · s.less(i, j) · s.greater(i, j) · s.lessV(i, v) · s.greaterV(i, v) · s.copy()")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.bottom, 8)
            Divider()
            if let c = current {
                CodeEditor(
                    text: textBinding,
                    initialSelection: model.justCreatedID == c.id ? AlgorithmStore.nameRange(in: c.source) : nil
                )
                .id(c.id)
            } else {
                Spacer()
            }
            if let err = saveError ?? current.flatMap({ model.fileErrors[$0.id] }) {
                Divider()
                Text(err)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.red.opacity(0.1))
            }
        }
        .frame(minWidth: 560, minHeight: 400)
        .confirmationDialog("Delete “\(current?.name ?? "")”?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let c = current { drafts[c.id] = nil; model.deleteAlgorithm(id: c.id) }
            }
        } message: {
            Text("This removes its file. It can't be undone.")
        }
    }

    private func save() {
        guard let c = current else { return }
        let text = drafts[c.id] ?? c.source
        saveError = model.saveAlgorithm(id: c.id, source: text)
        if saveError == nil { drafts[c.id] = nil }
    }
}

/// Plain monospaced NSTextView with smart quotes/dashes turned off (they break code).
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var initialSelection: NSRange?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let tv = scroll.documentView as! NSTextView
        tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 6, height: 8)
        tv.delegate = context.coordinator
        tv.string = text
        if let sel = initialSelection {
            DispatchQueue.main.async {
                tv.window?.makeFirstResponder(tv)
                tv.setSelectedRange(sel)
                tv.scrollRangeToVisible(sel)
            }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let tv = scroll.documentView as! NSTextView
        if tv.string != text {
            tv.string = text
            tv.textColor = .textColor
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        init(_ parent: CodeEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}
