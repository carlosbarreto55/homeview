import Foundation
import KSPlayer

/// Spike only: with `SPIKE_FFMPEG_LOG=1`, writes KSPlayer and FFmpeg messages
/// to stderr, with the DVR password removed (FFmpeg can print the full URL).
final class SpikeFFmpegLog: LogHandler {
    private let secrets: [String]

    init(secrets: [String]) {
        self.secrets = secrets.filter { !$0.isEmpty }
    }

    static func installIfRequested() {
        guard ProcessInfo.processInfo.environment["SPIKE_FFMPEG_LOG"] == "1" else { return }
        let password = SpikeCredentials.load()?.password ?? ""
        let encoded = password.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        KSOptions.logger = SpikeFFmpegLog(secrets: [password, encoded])
        KSOptions.logLevel = .debug
    }

    func log(level: LogLevel, message: CustomStringConvertible, file: String, function: String, line: UInt) {
        var text = message.description
        for secret in secrets {
            text = text.replacingOccurrences(of: secret, with: "***")
        }
        FileHandle.standardError.write(Data("[\(level)] \(text)\n".utf8))
    }
}
