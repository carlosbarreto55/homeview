import SwiftUI

struct PanelHeader: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            title
            Spacer(minLength: 8)
            if model.route.hasStreams {
                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Atualizar")
            }
            PanelMenu(model: model)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    @ViewBuilder
    private var title: some View {
        switch model.route {
        case .enlarged(let channel):
            Button {
                model.backToGrid()
            } label: {
                Text("‹ \(model.cameras.camera(channel: channel)?.name ?? Camera.defaultName(channel: channel))")
                    .font(.headline)
                    .lineLimit(1)
            }
            .help("Voltar para todas as câmeras")
        case .setup:
            Text("Configurar DVR").font(.headline)
        case .dvrSettings:
            Text("Configurações do DVR").font(.headline)
        case .renameCameras:
            Text("Renomear câmeras").font(.headline)
        case .grid, .loading:
            Text("Câmeras").font(.headline)
        }
    }
}

/// The "…" menu.
struct PanelMenu: View {
    let model: AppModel

    var body: some View {
        Menu {
            Button("Renomear câmeras") { model.openRenameCameras() }
                .disabled(model.settings == nil)
            Button("Configurações do DVR") { model.openDVRSettings() }
                .disabled(model.settings == nil)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Mais opções")
    }
}

struct PanelFooter: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            let status = model.status
            if status != .idle {
                Circle()
                    .fill(color(for: status))
                    .frame(width: 8, height: 8)
                Text(status.text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if status.offersFix {
                Button("Corrigir") { model.openDVRSettings() }
                    .controlSize(.small)
            }
            Spacer(minLength: 8)
            Button {
                SnapshotFolder.open()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Abrir a pasta de fotos")
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    private func color(for status: ConnectionStatus) -> Color {
        switch status {
        case .connected: .green
        case .connecting, .idle: .yellow
        case .unreachable, .wrongCredentials: .red
        }
    }
}
