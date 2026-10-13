import SwiftUI

/// One camera at the panel's full width, from its main stream. The header
/// shows "‹ Name" to go back to the grid.
struct EnlargedCameraView: View {
    let model: AppModel
    let channel: Int

    var body: some View {
        let session = model.session(channel: channel)
        ZStack {
            Color.black
            if let session {
                PlayerView(player: session.player)
            }
            TileStateOverlay(state: TileState(session: session?.state, isVerifying: model.isVerifying))
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            ChannelBadge(channel: channel)
                .padding(8)
        }
        .overlay(alignment: .bottom) {
            if let message = model.snapshotMessage {
                Label(message.text, systemImage: message == .saved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.7), in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.snapshotMessage)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(12)
    }
}
