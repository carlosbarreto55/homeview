import SwiftUI
import os

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
        // Spike only: `-spikeTogglePanel N` presses the menu bar button N
        // times, 6 s apart, opening and closing the real panel.
        let toggles = UserDefaults.standard.integer(forKey: "spikeTogglePanel")
        for index in 0..<toggles {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2 + 6 * Double(index)) {
                Logger.panel.info("spike: pressing the menu bar button (\(index + 1)/\(toggles))")
                Self.statusItemButton()?.performClick(nil)
            }
        }
    }

    private static func statusItemButton() -> NSButton? {
        for window in NSApp.windows where String(describing: type(of: window)).contains("StatusBar") {
            if let button = findButton(in: window.contentView) { return button }
        }
        return nil
    }

    private static func findButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton { return button }
        for subview in view.subviews {
            if let button = findButton(in: subview) { return button }
        }
        return nil
    }
}
