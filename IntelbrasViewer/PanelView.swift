import SwiftUI

/// The floating panel shown below the menu bar icon.
struct PanelView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "video")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Câmeras")
                .font(.headline)
        }
        .frame(width: 600, height: 340)
    }
}

#Preview {
    PanelView()
}
