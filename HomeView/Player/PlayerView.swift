import SwiftUI

/// Hosts a `CameraPlayer`'s view in SwiftUI.
struct PlayerView: NSViewRepresentable {
    let player: CameraPlayer

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        attach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        if player.view.superview !== container {
            attach(to: container)
        }
    }

    private func attach(to container: NSView) {
        container.subviews.forEach { $0.removeFromSuperview() }
        player.view.frame = container.bounds
        player.view.autoresizingMask = [.width, .height]
        container.addSubview(player.view)
    }
}
