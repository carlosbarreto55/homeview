import SwiftUI
import os

/// Spike only: plays one camera at 16:9 to validate the player on the real DVR.
@MainActor
@Observable
final class SpikeModel {
    let channel: Int
    let subtype: Int
    let player: CameraPlayer = KSCameraPlayer()
    private(set) var state: CameraPlayerState = .idle

    init(channel: Int, subtype: Int) {
        self.channel = channel
        self.subtype = subtype
        player.onStateChange = { [weak self] state in
            guard let self else { return }
            self.state = state
            Logger.player.info("state ch\(channel) \(String(describing: state), privacy: .public)")
            if state == .playing, let path = SpikeFrameDump.basePath {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    await SpikeFrameDump.dump(from: self.player, to: "\(path)-ch\(channel)")
                }
            }
        }
    }

    func start() {
        guard let url = SpikeCredentials.url(channel: channel, subtype: subtype) else {
            state = .failed(reason: "Sem credenciais no Keychain (\(SpikeCredentials.service))")
            Logger.player.error("no spike credentials in the Keychain")
            return
        }
        player.start(url: url)
    }

    func stop() {
        player.stop()
    }
}

/// Launch arguments: `-spikeAll YES` plays the 8 substreams in a grid;
/// otherwise `-spikeChannel N` (default 1) and `-spikeSubtype S` (default 1).
struct SpikeView: View {
    /// In the panel, streams follow the panel's visibility; in the spike
    /// window they start when the view appears.
    var followsPanelVisibility = false

    @State private var models: [SpikeModel] = {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "spikeAll") {
            return (1...8).map { SpikeModel(channel: $0, subtype: 1) }
        }
        let channel = max(1, defaults.integer(forKey: "spikeChannel"))
        let subtype = defaults.object(forKey: "spikeSubtype") == nil ? 1 : defaults.integer(forKey: "spikeSubtype")
        return [SpikeModel(channel: channel, subtype: subtype)]
    }()

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: models.count > 1 ? 2 : 1), spacing: 12) {
                ForEach(models, id: \.channel) { model in
                    SpikeTile(model: model)
                }
            }
            .padding(12)
        }
        .frame(width: 600, height: models.count > 1 ? 540 : 400)
        .background {
            if followsPanelVisibility {
                PanelVisibilityObserver { visible in
                    Logger.panel.info("panel \(visible ? "visible, starting" : "hidden, stopping", privacy: .public) streams")
                    models.forEach { visible ? $0.start() : $0.stop() }
                }
            }
        }
        .onAppear { if !followsPanelVisibility { models.forEach { $0.start() } } }
    }
}

private struct SpikeTile: View {
    let model: SpikeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Canal \(model.channel) · subtype \(model.subtype)")
                .font(.headline)
            PlayerView(player: model.player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(.black)
            Text(String(describing: model.state))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
