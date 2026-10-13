import AppKit
import SwiftUI
import os

/// Reports when the window hosting this view becomes visible or hidden, and
/// Esc pressed in it while no text field is being edited.
///
/// `MenuBarExtra(.window)` keeps its SwiftUI view alive between openings, so
/// `onAppear`/`onDisappear` do not mark each open and close. The window's
/// occlusion state does.
struct PanelVisibilityObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void
    var onEscape: () -> Void = {}

    func makeNSView(context: Context) -> ObservingView {
        ObservingView(onChange: onChange, onEscape: onEscape)
    }

    func updateNSView(_ view: ObservingView, context: Context) {
        view.onChange = onChange
        view.onEscape = onEscape
    }

    final class ObservingView: NSView {
        var onChange: (Bool) -> Void
        var onEscape: () -> Void
        private var observations: [NSObjectProtocol] = []
        private var keyMonitor: Any?
        private var isVisible: Bool?

        init(onChange: @escaping (Bool) -> Void, onEscape: @escaping () -> Void) {
            self.onChange = onChange
            self.onEscape = onEscape
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observations.forEach(NotificationCenter.default.removeObserver)
            observations = []
            guard let window else { return }
            let center = NotificationCenter.default
            observations.append(center.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            })
            // MenuBarExtra centers the panel under the icon each time it opens
            // or changes size; put it back where it belongs.
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                observations.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.placeWindow() }
                })
            }
            report()
        }

        override func removeFromSuperview() {
            stopWatchingKeys()
            super.removeFromSuperview()
        }

        /// Esc closes the panel, except while a text field is being edited
        /// (then the field gets it, ending the edit).
        private func watchKeys() {
            guard keyMonitor == nil else { return }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, event.window === window,
                      event.keyCode == 53 // Esc
                else { return event }
                if let editor = window.firstResponder as? NSTextView, editor.isFieldEditor {
                    return event
                }
                self.onEscape()
                return nil
            }
        }

        private func stopWatchingKeys() {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
        }

        /// Top-left corner at the menu bar icon's bottom-right corner.
        private func placeWindow() {
            guard let window, let icon = MenuBarPanel.iconFrame(),
                  let screen = window.screen ?? NSScreen.main
            else { return }
            let origin = MenuBarPanel.panelOrigin(panelSize: window.frame.size, iconFrame: icon,
                                                  screenFrame: screen.visibleFrame)
            if window.frame.origin != origin {
                window.setFrameOrigin(origin)
            }
        }

        private func report() {
            guard let window else { return }
            placeWindow()
            let visible = window.occlusionState.contains(.visible)
            Logger.panel.info("occlusion visible=\(visible)")
            guard visible != isVisible else { return }
            isVisible = visible
            if visible { watchKeys() } else { stopWatchingKeys() }
            onChange(visible)
        }
    }
}
