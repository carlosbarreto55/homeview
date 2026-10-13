import CoreGraphics
import Foundation

/// `<camera name> 2026-10-13 21.04.37.jpg`, with characters macOS does not
/// allow in file names replaced by "-".
enum SnapshotFileName {
    static func make(cameraName: String, date: Date, timeZone: TimeZone = .current) -> String {
        "\(sanitize(cameraName)) \(timestamp(date, timeZone: timeZone)).jpg"
    }

    static func sanitize(_ name: String) -> String {
        let replaced = name.unicodeScalars.map { scalar -> String in
            if scalar == "/" || scalar == ":" || CharacterSet.controlCharacters.contains(scalar) {
                return "-"
            }
            return String(scalar)
        }
        return replaced.joined()
    }

    private static func timestamp(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: date)
    }
}

/// Snapshot images have the 16:9 shape the person sees, at the stream's height.
enum SnapshotSize {
    static func output(forFrameWidth width: Int, height: Int) -> (width: Int, height: Int) {
        (Int((Double(height) * 16 / 9).rounded()), height)
    }
}
