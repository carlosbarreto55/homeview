import CryptoKit
import Foundation

/// HTTP Digest authentication (RFC 2617), as the DVR's RTSP server uses it.
enum DigestAuth {
    /// The parameters of a `WWW-Authenticate: Digest …` challenge.
    struct Challenge: Equatable {
        var realm: String
        var nonce: String
        var qop: String?
        var opaque: String?
        var algorithm: String?

        /// Parses a `WWW-Authenticate` header value. Returns `nil` when it is
        /// not a Digest challenge or lacks a realm or nonce.
        init?(header: String) {
            let trimmed = header.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().hasPrefix("digest ") else { return nil }
            let parameters = DigestAuth.parseParameters(String(trimmed.dropFirst("digest ".count)))
            guard let realm = parameters["realm"], let nonce = parameters["nonce"] else { return nil }
            self.realm = realm
            self.nonce = nonce
            opaque = parameters["opaque"]
            algorithm = parameters["algorithm"]
            // The server may offer several (`qop="auth,auth-int"`); only `auth` is supported.
            let offered = parameters["qop"]?
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? []
            qop = offered.contains("auth") ? "auth" : nil
        }

        init(realm: String, nonce: String, qop: String? = nil, opaque: String? = nil, algorithm: String? = nil) {
            self.realm = realm
            self.nonce = nonce
            self.qop = qop
            self.opaque = opaque
            self.algorithm = algorithm
        }
    }

    /// The `response` value for a request.
    static func response(
        challenge: Challenge, method: String, uri: String,
        user: String, password: String, nonceCount: Int = 1, clientNonce: String
    ) -> String {
        let ha1 = md5("\(user):\(challenge.realm):\(password)")
        let ha2 = md5("\(method):\(uri)")
        if let qop = challenge.qop {
            return md5("\(ha1):\(challenge.nonce):\(formatNonceCount(nonceCount)):\(clientNonce):\(qop):\(ha2)")
        }
        return md5("\(ha1):\(challenge.nonce):\(ha2)")
    }

    /// The value of the `Authorization` header for a request.
    static func authorization(
        challenge: Challenge, method: String, uri: String,
        user: String, password: String, nonceCount: Int = 1,
        clientNonce: String = makeClientNonce()
    ) -> String {
        let response = response(challenge: challenge, method: method, uri: uri, user: user,
                                password: password, nonceCount: nonceCount, clientNonce: clientNonce)
        var fields = [
            "username=\(quote(user))",
            "realm=\(quote(challenge.realm))",
            "nonce=\(quote(challenge.nonce))",
            "uri=\(quote(uri))",
            "response=\(quote(response))",
        ]
        if let qop = challenge.qop {
            fields += ["qop=\(qop)", "nc=\(formatNonceCount(nonceCount))", "cnonce=\(quote(clientNonce))"]
        }
        if let opaque = challenge.opaque {
            fields.append("opaque=\(quote(opaque))")
        }
        if let algorithm = challenge.algorithm {
            fields.append("algorithm=\(algorithm)")
        }
        return "Digest " + fields.joined(separator: ", ")
    }

    static func makeClientNonce() -> String {
        (0..<8).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    static func md5(_ text: String) -> String {
        Insecure.MD5.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func formatNonceCount(_ count: Int) -> String {
        String(format: "%08x", count)
    }

    private static func quote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Parses `key="quoted, value", key2=token` pairs; keys are lowercased.
    static func parseParameters(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        var index = text.startIndex

        func skip(_ characters: Set<Character>) {
            while index < text.endIndex, characters.contains(text[index]) { index = text.index(after: index) }
        }

        while index < text.endIndex {
            skip([" ", "\t", ","])
            let keyStart = index
            while index < text.endIndex, text[index] != "=", text[index] != "," { index = text.index(after: index) }
            let key = text[keyStart..<index].trimmingCharacters(in: .whitespaces).lowercased()
            guard index < text.endIndex, text[index] == "=" else { continue }
            index = text.index(after: index)
            skip([" ", "\t"])
            var value = ""
            if index < text.endIndex, text[index] == "\"" {
                index = text.index(after: index)
                while index < text.endIndex, text[index] != "\"" {
                    if text[index] == "\\", text.index(after: index) < text.endIndex {
                        index = text.index(after: index)
                    }
                    value.append(text[index])
                    index = text.index(after: index)
                }
                if index < text.endIndex { index = text.index(after: index) }
            } else {
                while index < text.endIndex, text[index] != "," {
                    value.append(text[index])
                    index = text.index(after: index)
                }
                value = value.trimmingCharacters(in: .whitespaces)
            }
            if !key.isEmpty { result[key] = value }
        }
        return result
    }
}
