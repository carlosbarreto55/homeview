import Foundation

/// The RTSP address of one camera stream on the DVR.
struct StreamURL: Equatable {
    enum Quality: Int {
        /// The light stream used by the grid (`subtype=1`).
        case substream = 1
        /// The full stream used by the enlarged view (`subtype=0`).
        case main = 0
    }

    var host: String
    var port: Int
    var user: String
    var password: String
    var channel: Int
    var quality: Quality

    /// `rtsp://user:password@HOST:PORT/cam/realmonitor?channel=N&subtype=S`,
    /// with the user and password percent-encoded. Never log this; use
    /// `logDescription`.
    var url: URL {
        let credentials = "\(Self.encode(user)):\(Self.encode(password))@"
        return URL(string: "rtsp://\(credentials)\(host):\(port)\(path)")!
    }

    /// The address without credentials, safe for logs.
    var logDescription: String {
        "rtsp://\(host):\(port)\(path)"
    }

    var path: String {
        "/cam/realmonitor?channel=\(channel)&subtype=\(quality.rawValue)"
    }

    /// Percent-encodes everything except RFC 3986 unreserved characters.
    static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}
