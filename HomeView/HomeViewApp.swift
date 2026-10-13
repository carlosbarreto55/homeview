import SwiftUI

@main
struct HomeViewApp: App {
    @State private var model = AppModel(makePlayer: { KSCameraPlayer() })

    var body: some Scene {
        MenuBarExtra("HomeView", systemImage: "video") {
            PanelView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
