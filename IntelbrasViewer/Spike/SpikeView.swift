import SwiftUI
import os

/// Spike only: plays one camera at 16:9 to validate the player on the real DVR.
/// Launch arguments: `-spikeChannel N` (default 1), `-spikeSubtype S` (default 1).
@MainActor
@Observable
final class SpikeModel {
    let channel: Int
    let subtype: Int
    let player: CameraPlayer = KSCameraPlayer()
    private(set) var state: CameraPlayerState = .idle

    init(defaults: UserDefaults = .standard) {
        channel = max(1, defaults.integer(forKey: "spikeChannel"))
        subtype = defaults.object(forKey: "spikeSubtype") == nil ? 1 : defaults.integer(forKey: "spikeSubtype")
        player.onStateChange = { [weak self] state in
            self?.state = state
            Logger.player.info("state \(String(describing: state), privacy: .public)")
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

struct SpikeView: View {
    @State private var model = SpikeModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Canal \(model.channel) · subtype \(model.subtype)")
                .font(.headline)
            PlayerView(player: model.player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(.black)
            Text(String(describing: model.state))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 600)
        .onAppear { model.start() }
    }
}
