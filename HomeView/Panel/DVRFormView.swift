import SwiftUI

/// "Configurar DVR" (first run) and "Configurações do DVR": address, port,
/// user and password, checked with the DVR before anything is saved.
struct DVRFormView: View {
    enum Mode {
        case setup
        case settings
    }

    let model: AppModel
    var mode = Mode.setup

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
            if mode == .setup {
                Text("Digite o endereço do DVR na sua rede e o usuário que o app deve usar.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
                    SecureField(mode == .settings ? "Deixe em branco para manter a atual" : "", text: $password)
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
                if mode == .settings {
                    Button("Esquecer DVR", role: .destructive) { model.forgetDVR() }
                        .disabled(isChecking)
                }
                if isChecking {
                    ProgressView().controlSize(.small)
                    Text("Verificando…").foregroundStyle(.secondary)
                }
                Spacer()
                if mode == .settings {
                    Button("Cancelar") { model.closeForm() }
                        .keyboardShortcut(.cancelAction)
                }
                Button(mode == .settings ? "Salvar" : "Conectar", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
        }
        .padding(20)
        .onSubmit(submit)
        .onAppear {
            let address = model.formAddress
            host = address.host
            port = String(address.port)
            user = mode == .settings ? model.settings?.credentials.user ?? "" : ""
            focusedField = mode == .settings ? .password : .user
        }
    }

    private var portNumber: Int? {
        Int(port).flatMap { (1...65535).contains($0) ? $0 : nil }
    }

    private var canSubmit: Bool {
        !isChecking && !host.trimmingCharacters(in: .whitespaces).isEmpty && portNumber != nil
            && !user.isEmpty && (mode == .settings || !password.isEmpty)
    }

    private func submit() {
        guard canSubmit, let portNumber else { return }
        isChecking = true
        error = nil
        Task {
            // The user name is kept exactly as typed: the DVR is case-sensitive.
            switch mode {
            case .setup:
                error = await model.connect(host: host, port: portNumber,
                                            credentials: Credentials(user: user, password: password))
            case .settings:
                error = await model.saveSettings(host: host, port: portNumber, user: user, password: password)
            }
            isChecking = false
        }
    }
}
