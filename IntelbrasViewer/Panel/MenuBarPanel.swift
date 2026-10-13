import AppKit

/// Controls the MenuBarExtra panel from code.
@MainActor
enum MenuBarPanel {
    /// Closes the panel by pressing the menu bar button, so SwiftUI's
    /// MenuBarExtra keeps its own open/closed state right.
    static func close() {
        statusItemButton()?.performClick(nil)
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
