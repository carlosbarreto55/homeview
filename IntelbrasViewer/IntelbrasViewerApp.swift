import SwiftUI

@main
struct IntelbrasViewerApp: App {
    @State private var model = AppModel(makePlayer: { KSCameraPlayer() })

    var body: some Scene {
        MenuBarExtra("Intelbras Viewer", systemImage: "video") {
            PanelView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
