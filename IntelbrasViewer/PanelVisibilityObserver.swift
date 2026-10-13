import AppKit
import SwiftUI
import os

/// Reports when the window hosting this view becomes visible or hidden.
///
/// `MenuBarExtra(.window)` keeps its SwiftUI view alive between openings, so
/// `onAppear`/`onDisappear` do not mark each open and close. The window's
/// occlusion state does.
struct PanelVisibilityObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ObservingView {
        ObservingView(onChange: onChange)
    }

    func updateNSView(_ view: ObservingView, context: Context) {
        view.onChange = onChange
    }

    final class ObservingView: NSView {
        var onChange: (Bool) -> Void
        private var observations: [NSObjectProtocol] = []
        private var isVisible: Bool?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
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
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                observations.append(center.addObserver(forName: name, object: window, queue: .main) { note in
                    Logger.panel.info("\(note.name.rawValue, privacy: .public)")
                })
            }
            report()
        }

        private func report() {
            guard let window else { return }
            let visible = window.occlusionState.contains(.visible)
            Logger.panel.info("occlusion visible=\(visible)")
            guard visible != isVisible else { return }
            isVisible = visible
            onChange(visible)
        }
    }
}
