import AppKit

/// Controls the MenuBarExtra panel from code.
@MainActor
enum MenuBarPanel {
    /// Closes the panel by pressing the menu bar button, so SwiftUI's
    /// MenuBarExtra keeps its own open/closed state right.
    static func close() {
        statusItemButton()?.performClick(nil)
    }

    /// The menu bar icon's frame in screen coordinates.
    static func iconFrame() -> NSRect? {
        guard let button = statusItemButton(), let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// Where the panel goes: its top-left corner at the icon's bottom-right
    /// corner, moved left only as much as needed to stay on screen.
    nonisolated static func panelOrigin(panelSize: NSSize, iconFrame: NSRect, screenFrame: NSRect) -> NSPoint {
        let x = min(iconFrame.maxX, screenFrame.maxX - panelSize.width)
        return NSPoint(x: max(x, screenFrame.minX), y: iconFrame.minY - panelSize.height)
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
