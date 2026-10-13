import SwiftUI

@main
struct IntelbrasViewerApp: App {
    var body: some Scene {
        MenuBarExtra("Intelbras Viewer", systemImage: "video") {
            PanelView()
        }
        .menuBarExtraStyle(.window)
    }
}
