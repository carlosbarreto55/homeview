import Foundation

/// The one status the panel footer shows.
enum ConnectionStatus: Equatable {
    /// Nothing is streaming (panel closed, or no visible cameras).
    case idle
    case connecting
    case connected
    case unreachable
    case wrongCredentials

    var text: String {
        switch self {
        case .idle: ""
        case .connecting: "Conectando…"
        case .connected: "Conectado"
        case .unreachable: "Sem conexão com o DVR"
        case .wrongCredentials: "Usuário ou senha incorretos"
        }
    }

    /// Whether the footer offers "Corrigir" (opens "Configurações do DVR").
    var offersFix: Bool {
        self == .wrongCredentials
    }

    /// - Parameters:
    ///   - sessions: the states of the current view's streams.
    ///   - lastProbe: the probe run after every stream failed, if it has
    ///     answered; `nil` while it has not run or is running.
    static func derive(sessions: [StreamSession.State], lastProbe: RTSPProbe.Result?) -> ConnectionStatus {
        let running = sessions.filter { $0 != .stopped }
        guard !running.isEmpty else { return .idle }
        if running.contains(.playing) { return .connected }
        if lastProbe == .wrongCredentials { return .wrongCredentials }
        if running.contains(.connecting) { return .connecting }
        // Every stream has failed: wait for the probe to say why.
        return lastProbe == nil ? .connecting : .unreachable
    }
}
