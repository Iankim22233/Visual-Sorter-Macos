import SwiftUI

struct ContentView: View {
    @ObservedObject var model: SortModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            AlgorithmTabs(
                items: model.algorithmNames.map { TabItem(id: $0, title: $0) },
                selection: model.algorithm,
                enabled: !model.isRunning,
                onSelect: { model.selectAlgorithm($0) },
                onNew: { model.newAlgorithm(); openWindow(id: "editor") }
            )
            Divider()
            BarsView(model: model)
            Divider()
            ControlsView(model: model)
                .padding(12)
                .background(.regularMaterial)
        }
        .frame(minWidth: 1020, minHeight: 440)
    }
}

struct BarsView: View {
    @ObservedObject var model: SortModel

    private func slot(_ p: CGPoint, _ size: CGSize) -> Int {
        let n = max(model.count, 1)
        if model.style == .pie {
            var a = atan2(p.y - size.height / 2, p.x - size.width / 2) + .pi / 2
            if a < 0 { a += 2 * .pi }
            return min(n - 1, Int(a / (2 * .pi) * Double(n)))
        }
        return min(max(Int(p.x / (size.width / CGFloat(n))), 0), n - 1)
    }

    var body: some View {
        GeometryReader { geo in
            canvas
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            model.dragBegan(at: slot(v.startLocation, geo.size))
                            model.dragMoved(to: slot(v.location, geo.size))
                        }
                        .onEnded { _ in model.dragEnded() }
                )
        }
    }

    private var canvas: some View {
        Canvas { ctx, size in
            _ = model.frame
            let values = model.displayValues
            let n = values.count
            guard n > 0 else { return }
            let markA = model.markA, markB = model.markB
            let sortedCount = model.sortedCount, rainbow = model.rainbow

            func color(_ i: Int, _ frac: CGFloat) -> Color {
                if i == markA || i == markB { return .white }
                if i < sortedCount { return .green }
                return rainbow ? Color(hue: 0.78 * frac, saturation: 0.75, brightness: 0.95)
                                     : Color(white: 0.3 + 0.65 * frac)
            }
            func fraction(_ v: Int) -> CGFloat { min(max(CGFloat(v) / CGFloat(n), 0), 1) }

            switch model.style {
            case .bars:
                let w = size.width / CGFloat(n)
                let gap: CGFloat = w > 4 ? 1 : 0
                for (i, v) in values.enumerated() {
                    let frac = fraction(v)
                    let h = size.height * frac
                    let rect = CGRect(x: CGFloat(i) * w, y: size.height - h, width: max(w - gap, 0.6), height: h)
                    ctx.fill(Path(rect), with: .color(color(i, frac)))
                }

            case .dots:
                let w = size.width / CGFloat(n)
                let r = min(max(w * 0.45, 1.5), 7)
                let usable = size.height - 2 * r
                for (i, v) in values.enumerated() {
                    let frac = fraction(v)
                    let c = CGPoint(x: (CGFloat(i) + 0.5) * w, y: size.height - r - usable * frac)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                             with: .color(color(i, frac)))
                }

            case .line:
                let w = size.width / CGFloat(n)
                var path = Path()
                for (i, v) in values.enumerated() {
                    let p = CGPoint(x: (CGFloat(i) + 0.5) * w, y: size.height - size.height * fraction(v))
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                ctx.stroke(path, with: .color(Color(white: 0.8)), lineWidth: 1.5)
                for i in [markA, markB] where i >= 0 && i < n {
                    let p = CGPoint(x: (CGFloat(i) + 0.5) * w, y: size.height - size.height * fraction(values[i]))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(.white))
                }
                if sortedCount > 0 {
                    var done = Path()
                    for i in 0..<min(sortedCount, n) {
                        let p = CGPoint(x: (CGFloat(i) + 0.5) * w, y: size.height - size.height * fraction(values[i]))
                        if i == 0 { done.move(to: p) } else { done.addLine(to: p) }
                    }
                    ctx.stroke(done, with: .color(.green), lineWidth: 2.5)
                }

            case .pie:
                // Each slice is one line; its color shows the value. A sorted pie is a smooth color wheel.
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 8
                let step = 2 * Double.pi / Double(n)
                for (i, v) in values.enumerated() {
                    let start = Angle(radians: -Double.pi / 2 + Double(i) * step)
                    let end = Angle(radians: -Double.pi / 2 + Double(i + 1) * step + 0.004)
                    var slice = Path()
                    slice.move(to: center)
                    slice.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                    slice.closeSubpath()
                    ctx.fill(slice, with: .color(color(i, fraction(v))))
                }
            }
        }
        .background(Color.black)
    }
}

struct ControlsView: View {
    @ObservedObject var model: SortModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Menu {
                    ForEach(model.algorithmNames, id: \.self) { name in
                        Button {
                            model.selectAlgorithm(name)
                        } label: {
                            if name == model.algorithm { Label(name, systemImage: "checkmark") } else { Text(name) }
                        }
                    }
                    Divider()
                    Button("New Algorithm…") { model.newAlgorithm(); openWindow(id: "editor") }
                    Button("Edit “\(model.algorithm)”…") { openWindow(id: "editor") }
                } label: {
                    Text(model.algorithm).lineLimit(1)
                }
                .frame(width: 210)
                .disabled(model.isRunning)

                Picker("Style", selection: $model.style) {
                    ForEach(VisualStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(width: 130)

                Button("Scramble") { model.scramble() }
                    .disabled(model.isRunning)

                if model.isRunning {
                    Button("Stop") { model.stop() }
                        .keyboardShortcut(.escape, modifiers: [])
                } else {
                    Button("Sort") { model.sort() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(model.manual)
                }

                Toggle("Manual sort", isOn: $model.manual)
                    .toggleStyle(.button)
                    .help("Click a line and drag it to a new position, then let go to drop it.")

                Button("Reset") { model.reset() }

                Button("Edit Code…") { openWindow(id: "editor") }
            }

            HStack(spacing: 18) {
                labeled("Lines") {
                    Slider(value: Binding(get: { Double(model.count) },
                                          set: { model.setCount(Int($0)) }),
                           in: 4...1000, step: 1)
                } field: {
                    NumberField(value: Double(model.count), range: 4...1000) { model.setCount(Int($0.rounded())) }
                }
                labeled("Speed") {
                    Slider(value: $model.speedT, in: 0...1)
                } field: {
                    NumberField(value: model.speed, range: 5...10_000, suffix: "ops/s") {
                        model.speedT = log($0 / 5) / log(2000)
                    }
                }
                labeled("Sweep") {
                    Slider(value: $model.sweepT, in: 0...1)
                } field: {
                    NumberField(value: model.sweepDuration, range: 0.2...6, decimals: 1, suffix: "s") {
                        model.sweepT = log($0 / 0.2) / log(30)
                    }
                }
                .help("How long the green completion sweep takes")
                HStack(spacing: 6) {
                    Button { model.muted.toggle() } label: {
                        Image(systemName: model.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(width: 18)
                    }
                    .buttonStyle(.borderless)
                    Slider(value: $model.volume, in: 0...1).frame(width: 80)
                    NumberField(value: model.volume * 100, range: 0...100, suffix: "%", width: 44) {
                        model.volume = $0 / 100
                    }
                }
                Toggle("Rainbow", isOn: $model.rainbow).toggleStyle(.checkbox)
            }

            HStack {
                Text(model.manual && model.message.isEmpty ? "Manual mode: click a line and drag it to where it belongs." : model.message)
                    .font(.callout)
                    .foregroundStyle(model.message.hasPrefix("Error") ? Color.red : .secondary)
                Spacer(minLength: 0)
                Text(model.manual ? "Moves \(model.moves)" : "Comparisons \(model.comparisons)  ·  Writes \(model.writes)")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func labeled<C: View, F: View>(_ title: String, @ViewBuilder _ content: () -> C,
                                              @ViewBuilder field: () -> F) -> some View {
        HStack(spacing: 8) {
            Text(title)
            content()
            field()
        }
    }
}

/// A number box that sits next to a slider. Type a value and press Return (or click away) to apply it;
/// out-of-range values are clamped. While you're not typing it follows the slider.
struct NumberField: View {
    let value: Double
    let range: ClosedRange<Double>
    var decimals = 0
    var suffix = ""
    var width: CGFloat = 58
    let commit: (Double) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private func format(_ v: Double) -> String { String(format: "%.\(decimals)f", v) }

    private func apply() {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if let v = Double(cleaned) {
            let clamped = min(max(v, range.lowerBound), range.upperBound)
            commit(clamped)
            text = format(clamped)
        } else {
            text = format(value)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .font(.system(.callout, design: .monospaced))
                .frame(width: width)
                .focused($focused)
                .onSubmit { apply() }
                .onChange(of: focused) { isFocused in if !isFocused { apply() } }
                .onChange(of: value) { new in if !focused { text = format(new) } }
                .onAppear { text = format(value) }
            if !suffix.isEmpty {
                Text(suffix).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

struct TabItem: Identifiable, Equatable {
    let id: String
    var title: String
    var modified = false
    var error = false
}

/// Horizontally scrolling row of tabs with a "+" button on the right.
struct AlgorithmTabs: View {
    let items: [TabItem]
    let selection: String?
    var enabled = true
    let onSelect: (String) -> Void
    let onNew: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(items) { item in
                            let selected = item.id == selection
                            Button { onSelect(item.id) } label: {
                                HStack(spacing: 5) {
                                    if item.error { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                                    Text(item.title)
                                    if item.modified { Circle().frame(width: 6, height: 6) }
                                }
                                .font(.callout)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(Capsule().fill(selected ? Color.accentColor : Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .onChange(of: selection) { sel in
                    if let sel { withAnimation { proxy.scrollTo(sel, anchor: .center) } }
                }
            }
            Button(action: onNew) { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .help("New algorithm")
                .padding(.trailing, 10)
        }
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .disabled(!enabled)
    }
}
