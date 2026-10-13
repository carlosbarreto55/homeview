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
            Text("Configurar DVR")
                .frame(maxWidth: .infinity, minHeight: 200)
        case .grid:
            CameraGridView(model: model)
        case .enlarged(let channel):
            EnlargedCameraView(model: model, channel: channel)
        case .dvrSettings:
            FormPlaceholder(title: "Configurações do DVR", model: model)
        case .renameCameras:
            FormPlaceholder(title: "Renomear câmeras", model: model)
        }
    }
}

extension EnvironmentValues {
    /// Set when the panel is rendered to an image (no scroll views).
    @Entry var rendersStatically = false
}

struct CameraGridView: View {
    let model: AppModel
    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        if rendersStatically {
            grid
        } else {
            ScrollView { grid }
                .frame(maxHeight: 540)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(model.cameras.visibleCameras) { camera in
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if let session = model.session(channel: camera.channel) {
                            PlayerView(player: session.player)
                        } else {
                            Color.black
                        }
                    }
                    .aspectRatio(16 / 9, contentMode: .fit)
                    Text(camera.name)
                        .font(.caption)
                }
                .contentShape(Rectangle())
                .onTapGesture { model.openCamera(channel: camera.channel) }
            }
        }
        .padding(12)
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
