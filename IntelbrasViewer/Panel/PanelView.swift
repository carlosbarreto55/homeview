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
            FormPlaceholder(title: "Renomear câmeras", model: model)
        }
    }
}

struct EnlargedCameraView: View {
    let model: AppModel
    let channel: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let session = model.session(channel: channel) {
                    PlayerView(player: session.player)
                } else {
                    Color.black
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
        }
        .padding(12)
    }
}

private struct FormPlaceholder: View {
    let title: String
    let model: AppModel

    var body: some View {
        VStack {
            Button("Cancelar") { model.closeForm() }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}
