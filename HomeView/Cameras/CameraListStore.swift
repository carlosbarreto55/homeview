import Foundation
import Observation

struct Camera: Codable, Equatable, Identifiable {
    var channel: Int
    var name: String
    var isVisible: Bool

    var id: Int { channel }

    static func defaultName(channel: Int) -> String {
        "Canal \(channel)"
    }
}

/// The DVR's 8 channels with the names and visibility the person chose,
/// saved as JSON in preferences (the restricted DVR user cannot read the
/// DVR's own channel names).
@Observable
final class CameraListStore {
    static let channels = 1...8
    static let maxNameLength = 30
    private static let key = "cameras"

    private(set) var cameras: [Camera]
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Camera].self, from: $0) } ?? []
        cameras = Self.channels.map { channel in
            let camera = saved.first { $0.channel == channel }
            return Camera(channel: channel,
                          name: Self.normalizedName(camera?.name ?? "", channel: channel),
                          isVisible: camera?.isVisible ?? true)
        }
    }

    var visibleCameras: [Camera] {
        cameras.filter(\.isVisible)
    }

    func camera(channel: Int) -> Camera? {
        cameras.first { $0.channel == channel }
    }

    /// Applies the names and visibility edited in "Renomear câmeras" and saves them.
    func apply(_ edited: [Camera]) {
        cameras = cameras.map { current in
            guard let edit = edited.first(where: { $0.channel == current.channel }) else { return current }
            return Camera(channel: current.channel,
                          name: Self.normalizedName(edit.name, channel: current.channel),
                          isVisible: edit.isVisible)
        }
        if let data = try? JSONEncoder().encode(cameras) {
            defaults.set(data, forKey: Self.key)
        }
    }

    /// Trimmed, at most 30 characters, and "Canal N" when empty.
    static func normalizedName(_ name: String, channel: Int) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(trimmed.prefix(maxNameLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        return limited.isEmpty ? Camera.defaultName(channel: channel) : limited
    }
}
