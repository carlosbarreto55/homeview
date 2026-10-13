import SwiftUI

/// "Renomear câmeras": a name and a "Mostrar" switch for each channel,
/// applied only on "Concluído".
struct RenameCamerasView: View {
    let model: AppModel
    @State private var draft: [Camera] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach($draft) { $camera in
                    GridRow {
                        ChannelBadge(channel: camera.channel)
                        TextField(Camera.defaultName(channel: camera.channel), text: $camera.name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: camera.name) { _, name in
                                if name.count > CameraListStore.maxNameLength {
                                    camera.name = String(name.prefix(CameraListStore.maxNameLength))
                                }
                            }
                        Toggle("Mostrar", isOn: $camera.isVisible)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancelar") { model.closeForm() }
                    .keyboardShortcut(.cancelAction)
                Button("Concluído") { model.finishRenaming(draft) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear { draft = model.cameras.cameras }
    }
}
