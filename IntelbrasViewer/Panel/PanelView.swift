import SwiftUI

/// The floating panel shown below the menu bar icon.
struct PanelView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(model: model)
            Divider()
            content
            if model.route.hasStreams {
                Divider()
                PanelFooter(model: model)
            }
        }
        .frame(width: 600)
            .background {
                PanelVisibilityObserver(onChange: model.panelVisibilityChanged, onEscape: MenuBarPanel.close)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.route {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        case .setup:
            DVRFormView(model: model)
        case .grid:
            CameraGridView(model: model)
        case .enlarged(let channel):
            EnlargedCameraView(model: model, channel: channel)
        case .dvrSettings:
            DVRFormView(model: model, mode: .settings)
        case .renameCameras:
            RenameCamerasView(model: model)
        }
    }
}
