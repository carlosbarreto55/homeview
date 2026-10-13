import SwiftUI

extension EnvironmentValues {
    /// Set when the panel is rendered to an image (no scroll views).
    @Entry var rendersStatically = false
}

/// The visible cameras live, two per row, scrolling past 540 pt.
struct CameraGridView: View {
    let model: AppModel
    @Environment(\.rendersStatically) private var rendersStatically

    static let spacing: CGFloat = 12
    static let maxHeight: CGFloat = 540

    var body: some View {
        let cameras = model.cameras.visibleCameras
        if cameras.isEmpty {
            emptyState
        } else if rendersStatically {
            grid(cameras)
        } else {
            ScrollView {
                grid(cameras)
            }
            .frame(height: min(Self.contentHeight(count: cameras.count), Self.maxHeight))
        }
    }

    private func grid(_ cameras: [Camera]) -> some View {
        let column = GridItem(.flexible(), spacing: Self.spacing)
        return LazyVGrid(columns: [column, column], spacing: Self.spacing) {
            ForEach(cameras) { camera in
                Button {
                    model.openCamera(channel: camera.channel)
                } label: {
                    CameraTile(camera: camera, session: model.session(channel: camera.channel),
                               isVerifying: model.isVerifying)
                }
                .buttonStyle(.plain)
                .help("Ampliar \(camera.name)")
            }
        }
        .padding(Self.spacing)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Nenhuma câmera visível")
                .font(.headline)
            Button("Escolher câmeras") { model.openRenameCameras() }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    /// The grid's height without scrolling, for a 600 pt wide panel.
    static func contentHeight(count: Int, panelWidth: CGFloat = 600) -> CGFloat {
        let rows = CGFloat((count + 1) / 2)
        let tileHeight = (panelWidth - spacing * 3) / 2 * 9 / 16
        return rows * tileHeight + max(0, rows - 1) * spacing + spacing * 2
    }
}

/// One camera in the grid: its picture at 16:9, channel badge and name.
struct CameraTile: View {
    let camera: Camera
    let session: StreamSession?
    let isVerifying: Bool
    @State private var isHovered = false

    var body: some View {
        ZStack {
            Color.black
            if let session {
                PlayerView(player: session.player)
            }
            overlay
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            ChannelBadge(channel: camera.channel)
                .padding(6)
        }
        .overlay(alignment: .bottomLeading) {
            Text(camera.name)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .shadow(radius: 2)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.white.opacity(isHovered ? 0.6 : 0), lineWidth: 2)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var overlay: some View {
        switch TileState(session: session?.state, isVerifying: isVerifying) {
        case .connecting:
            VStack(spacing: 6) {
                ProgressView().controlSize(.small).tint(.white)
                Text("Conectando…")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
        case .noSignal:
            VStack(spacing: 6) {
                Image(systemName: "video.slash")
                Text("Sem sinal")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
        case .playing:
            EmptyView()
        }
    }
}

/// What a tile shows over its picture.
enum TileState: Equatable {
    case connecting
    case noSignal
    case playing

    init(session: StreamSession.State?, isVerifying: Bool) {
        switch session {
        case .playing: self = .playing
        case .connecting: self = .connecting
        case .failed, .stopped: self = .noSignal
        case nil: self = isVerifying ? .connecting : .noSignal
        }
    }
}

struct ChannelBadge: View {
    let channel: Int

    var body: some View {
        Text("\(channel)")
            .font(.caption2.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
    }
}
