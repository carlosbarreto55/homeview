import Foundation

/// Checks a DVR address and login with one authenticated RTSP request, and
/// tells apart the failures setup needs to explain.
struct RTSPProbe {
    enum Result: Equatable {
        case ok
        case wrongCredentials
        case notFound
        case localNetworkDenied
    }

    var makeConnection: (_ host: String, _ port: Int) -> RTSPConnection = {
        NetworkRTSPConnection(host: $0, port: $1)
    }
    var timeout: Duration = .seconds(5)

    func check(host: String, port: Int, user: String, password: String) async -> Result {
        let connection = makeConnection(host, port)
        return await withTaskGroup(of: Result?.self) { group in
            group.addTask {
                await describe(on: connection, host: host, port: port, user: user, password: password)
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            // Cancel first, so a request ended by `close()` does not reconnect;
            // closing ends a request still waiting, so the group can finish.
            group.cancelAll()
            connection.close()
            if let first { return first }
            return connection.isLocalNetworkDenied ? .localNetworkDenied : .notFound
        }
    }

    /// DESCRIBE channel 1's substream; when challenged, answer once.
    private func describe(
        on connection: RTSPConnection, host: String, port: Int, user: String, password: String
    ) async -> Result {
        let uri = StreamURL(host: host, port: port, user: user, password: password,
                            channel: 1, quality: .substream).logDescription
        do {
            try await connection.open()
            let challenge = try await connection.send(Self.request(uri: uri, sequence: 1))
            guard challenge.statusCode == 401 else { return .ok }
            guard let authorization = Self.authorization(for: challenge, uri: uri, user: user, password: password) else {
                return .notFound
            }
            let request = Self.request(uri: uri, sequence: 2, authorization: authorization)
            let answer: RTSPResponse
            do {
                answer = try await connection.send(request)
            } catch RTSPConnectionError.closed where !Task.isCancelled {
                // Some servers close the connection after a 401; ask again on a new one.
                let retry = makeConnection(host, port)
                defer { retry.close() }
                try await retry.open()
                answer = try await retry.send(request)
            }
            return answer.statusCode == 401 ? .wrongCredentials : .ok
        } catch RTSPConnectionError.localNetworkDenied {
            return .localNetworkDenied
        } catch {
            return connection.isLocalNetworkDenied ? .localNetworkDenied : .notFound
        }
    }

    static func request(uri: String, sequence: Int, authorization: String? = nil) -> String {
        var lines = [
            "DESCRIBE \(uri) RTSP/1.0",
            "CSeq: \(sequence)",
            "User-Agent: IntelbrasViewer",
            "Accept: application/sdp",
        ]
        if let authorization {
            lines.append("Authorization: \(authorization)")
        }
        return lines.joined(separator: "\r\n") + "\r\n\r\n"
    }

    private static func authorization(for response: RTSPResponse, uri: String, user: String, password: String) -> String? {
        let offers = response.values(of: "WWW-Authenticate")
        if let challenge = offers.lazy.compactMap(DigestAuth.Challenge.init(header:)).first {
            return DigestAuth.authorization(challenge: challenge, method: "DESCRIBE", uri: uri,
                                            user: user, password: password)
        }
        if offers.contains(where: { $0.lowercased().hasPrefix("basic") }) {
            return "Basic " + Data("\(user):\(password)".utf8).base64EncodedString()
        }
        return nil
    }
}
