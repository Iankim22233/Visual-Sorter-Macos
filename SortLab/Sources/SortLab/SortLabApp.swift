import SwiftUI

@main
struct SortLabApp: App {
    @StateObject private var model = SortModel()

    var body: some Scene {
        WindowGroup("SortLab") {
            ContentView(model: model)
        }
        .defaultSize(width: 1000, height: 640)

        Window("Algorithm Editor", id: "editor") {
            EditorView(model: model)
        }
        .defaultSize(width: 760, height: 620)
    }
}
