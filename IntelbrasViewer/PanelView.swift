import SwiftUI

/// The floating panel shown below the menu bar icon.
struct PanelView: View {
    let model: AppModel

    var body: some View {
        content
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

struct CameraGridView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
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
        .frame(maxHeight: 540)
    }
}

struct EnlargedCameraView: View {
    let model: AppModel
    let channel: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("‹ \(model.cameras.camera(channel: channel)?.name ?? Camera.defaultName(channel: channel))") {
                model.backToGrid()
            }
            .buttonStyle(.plain)
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
            Text(title)
            Button("Cancelar") { model.closeForm() }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}
