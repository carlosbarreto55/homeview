import Foundation

struct DVRSettings: Equatable {
    static let defaultHost = "192.168.1.2"
    static let defaultPort = 554

    var host: String
    var port: Int
    var credentials: Credentials

    func streamURL(channel: Int, quality: StreamURL.Quality) -> StreamURL {
        StreamURL(host: host, port: port, user: credentials.user, password: credentials.password,
                  channel: channel, quality: quality)
    }
}

/// The DVR's address in preferences and its login in the Keychain. The
/// password never goes into preferences.
struct DVRSettingsStore {
    private enum Key {
        static let host = "dvr.host"
        static let port = "dvr.port"
    }

    var defaults: UserDefaults = .standard
    var keychain = KeychainStore()

    /// The saved settings, or `nil` when no login is saved (first-run setup).
    func load() throws -> DVRSettings? {
        guard let credentials = try keychain.read() else { return nil }
        let address = savedAddress
        return DVRSettings(host: address.host, port: address.port, credentials: credentials)
    }

    /// The saved address, or the defaults used to prefill setup.
    var savedAddress: (host: String, port: Int) {
        let host = defaults.string(forKey: Key.host) ?? DVRSettings.defaultHost
        let port = defaults.object(forKey: Key.port) as? Int ?? DVRSettings.defaultPort
        return (host, port)
    }

    func save(_ settings: DVRSettings) throws {
        try keychain.save(settings.credentials)
        defaults.set(settings.host, forKey: Key.host)
        defaults.set(settings.port, forKey: Key.port)
    }

    /// Removes the login and the saved address.
    func forget() throws {
        try keychain.delete()
        defaults.removeObject(forKey: Key.host)
        defaults.removeObject(forKey: Key.port)
    }
}
