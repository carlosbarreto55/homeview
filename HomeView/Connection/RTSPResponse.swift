import Foundation

/// An RTSP response: status line, headers and body.
struct RTSPResponse: Equatable {
    struct Header: Equatable {
        var name: String
        var value: String
    }

    var statusCode: Int
    var headers: [Header]
    var body: Data

    /// Every value of a header, matched without regard to case.
    func values(of name: String) -> [String] {
        headers.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }.map(\.value)
    }

    enum ParseError: Error {
        case invalidResponse
    }

    /// Removes one complete response from the front of `buffer` and returns it,
    /// or returns `nil` (leaving `buffer` as is) when more data is needed.
    static func extract(from buffer: inout Data) throws -> RTSPResponse? {
        guard let headEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let head = String(data: buffer[buffer.startIndex..<headEnd.lowerBound], encoding: .utf8) else {
            throw ParseError.invalidResponse
        }
        var lines = head.components(separatedBy: "\r\n")
        let statusParts = lines.removeFirst().split(separator: " ", maxSplits: 2)
        guard statusParts.count >= 2, statusParts[0].hasPrefix("RTSP/"),
              let statusCode = Int(statusParts[1])
        else { throw ParseError.invalidResponse }

        let headers = lines.compactMap { line -> Header? in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            return Header(name: line[..<colon].trimmingCharacters(in: .whitespaces),
                          value: line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
        }
        let length = headers.first { $0.name.caseInsensitiveCompare("Content-Length") == .orderedSame }
            .flatMap { Int($0.value) } ?? 0
        let bodyStart = headEnd.upperBound
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= length else { return nil }
        let bodyEnd = buffer.index(bodyStart, offsetBy: length)
        let response = RTSPResponse(statusCode: statusCode, headers: headers, body: Data(buffer[bodyStart..<bodyEnd]))
        buffer = Data(buffer[bodyEnd...])
        return response
    }
}
