import SwiftUI

/// "Configurar DVR": address, port, user and password, checked with the DVR
/// before anything is saved.
struct DVRFormView: View {
    let model: AppModel

    @State private var host = ""
    @State private var port = ""
    @State private var user = ""
    @State private var password = ""
    @State private var isChecking = false
    @State private var error: AppModel.SettingsError?
    @FocusState private var focusedField: Field?

    private enum Field {
        case host, port, user, password
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Digite o endereço do DVR na sua rede e o usuário que o app deve usar.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Endereço").gridColumnAlignment(.trailing)
                    TextField("192.168.1.2", text: $host)
                        .focused($focusedField, equals: .host)
                }
                GridRow {
                    Text("Porta")
                    TextField("554", text: $port)
                        .frame(width: 80)
                        .focused($focusedField, equals: .port)
                        .onChange(of: port) { _, new in
                            let digits = String(new.filter(\.isNumber).prefix(5))
                            if digits != new { port = digits }
                        }
                }
                GridRow {
                    Text("Usuário")
                    TextField("", text: $user)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .user)
                }
                GridRow {
                    Text("Senha")
                    SecureField("", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                }
            }
            .textFieldStyle(.roundedBorder)
            .disabled(isChecking)

            if let error {
                Label(error.message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if isChecking {
                    ProgressView().controlSize(.small)
                    Text("Verificando…").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Conectar", action: connect)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
        }
        .padding(20)
        .onSubmit(connect)
        .onAppear {
            let address = model.formAddress
            host = address.host
            port = String(address.port)
            focusedField = .user
        }
    }

    private var portNumber: Int? {
        Int(port).flatMap { (1...65535).contains($0) ? $0 : nil }
    }

    private var canSubmit: Bool {
        !isChecking && !host.trimmingCharacters(in: .whitespaces).isEmpty && portNumber != nil
            && !user.isEmpty && !password.isEmpty
    }

    private func connect() {
        guard canSubmit, let portNumber else { return }
        isChecking = true
        error = nil
        Task {
            // The user name is kept exactly as typed: the DVR is case-sensitive.
            error = await model.connect(host: host, port: portNumber,
                                        credentials: Credentials(user: user, password: password))
            isChecking = false
        }
    }
}
