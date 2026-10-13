import SwiftUI

@main
struct IntelbrasViewerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Intelbras Viewer", systemImage: "video") {
            PanelView()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var spikeWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Spike only: `-spikeWindow YES` shows the panel content in a normal
        // window, so it can be checked without clicking the menu bar.
        SpikeFFmpegLog.installIfRequested()
        if UserDefaults.standard.bool(forKey: "spikeWindow") {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SpikeView()))
            window.title = "Intelbras Viewer (spike)"
            window.makeKeyAndOrderFront(nil)
            spikeWindow = window
        }
    }
}
