import Foundation
import Network

enum RTSPConnectionError: Error, Equatable {
    case refused
    case unreachable
    case localNetworkDenied
    case closed
    case invalidResponse
}

/// One TCP connection to an RTSP server, sending a request and reading its
/// response at a time. Injectable so `RTSPProbe` can be tested without a DVR.
protocol RTSPConnection: AnyObject {
    /// Whether macOS has refused this app access to the local network for
    /// this connection (the connection waits instead of failing).
    var isLocalNetworkDenied: Bool { get }
    func open() async throws
    func send(_ request: String) async throws -> RTSPResponse
    /// Ends the connection; a pending `open` or `send` throws `.closed`.
    func close()
}

/// `RTSPConnection` over Network.framework.
final class NetworkRTSPConnection: RTSPConnection, @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.carloseduardo.IntelbrasViewer.rtsp")
    // Only touched on `queue`.
    private var buffer = Data()
    private var localNetworkDenied = false

    init(host: String, port: Int) {
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(clamping: port)) ?? 554,
            using: .tcp
        )
    }

    var isLocalNetworkDenied: Bool {
        queue.sync { localNetworkDenied }
    }

    func open() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            func finish(_ result: Result<Void, Error>) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(with: result)
            }
            connection.stateUpdateHandler = { [weak self, connection] state in
                switch state {
                case .ready:
                    finish(.success(()))
                case .waiting(let error):
                    if connection.currentPath?.unsatisfiedReason == .localNetworkDenied {
                        // Keep waiting: the person may be answering macOS's prompt.
                        self?.localNetworkDenied = true
                    } else {
                        finish(.failure(Self.map(error)))
                    }
                case .failed(let error):
                    finish(.failure(Self.map(error)))
                case .cancelled:
                    finish(.failure(RTSPConnectionError.closed))
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ request: String) async throws -> RTSPResponse {
        try await withCheckedThrowingContinuation { continuation in
            connection.send(content: Data(request.utf8), completion: .contentProcessed { [weak self] error in
                guard let self, error == nil else {
                    continuation.resume(throwing: RTSPConnectionError.closed)
                    return
                }
                self.receive(continuation)
            })
        }
    }

    func close() {
        connection.cancel()
    }

    private func receive(_ continuation: CheckedContinuation<RTSPResponse, Error>) {
        do {
            if let response = try RTSPResponse.extract(from: &buffer) {
                continuation.resume(returning: response)
                return
            }
        } catch {
            continuation.resume(throwing: RTSPConnectionError.invalidResponse)
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data { self.buffer.append(data) }
            if error != nil || (isComplete && (data?.isEmpty ?? true)) {
                continuation.resume(throwing: RTSPConnectionError.closed)
                return
            }
            self.receive(continuation)
        }
    }

    private static func map(_ error: NWError) -> RTSPConnectionError {
        if case .posix(let code) = error {
            switch code {
            case .ECONNREFUSED: return .refused
            case .ECANCELED: return .closed
            default: return .unreachable
            }
        }
        return .unreachable
    }
}
