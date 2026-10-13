import Foundation
import Security

/// Spike only: the DVR login comes from the environment, filled from a
/// Keychain item made by hand with
///
///     security add-generic-password -s com.carloseduardo.IntelbrasViewer.spike -a macapp -A -w
///
/// and passed in by `Scripts/spike-run.sh`. Reading that item from the app
/// itself makes macOS ask for permission (the item's partition list only
/// trusts Apple tools), so the script reads it with `security` instead.
/// Replaced by `DVRSettingsStore` later.
enum SpikeCredentials {
    static let service = "com.carloseduardo.IntelbrasViewer.spike"
    /// `SPIKE_DVR_HOST` / `SPIKE_DVR_PORT` point the spike at another server
    /// (used by `Scripts/fake-rtsp-digest.py`).
    static var host: String {
        ProcessInfo.processInfo.environment["SPIKE_DVR_HOST"] ?? "192.168.1.2"
    }

    static var port: Int {
        ProcessInfo.processInfo.environment["SPIKE_DVR_PORT"].flatMap(Int.init) ?? 554
    }

    static func load() -> (user: String, password: String)? {
        let environment = ProcessInfo.processInfo.environment
        if let password = environment["SPIKE_DVR_PASSWORD"] {
            return (environment["SPIKE_DVR_USER"] ?? "macapp", password)
        }
        return loadFromKeychain()
    }

    private static func loadFromKeychain() -> (user: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let item = result as? [String: Any],
              let user = item[kSecAttrAccount as String] as? String,
              let data = item[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8)
        else { return nil }
        return (user, password)
    }

    static func url(channel: Int, subtype: Int) -> URL? {
        guard let login = load() else { return nil }
        return StreamURL(host: host, port: port, user: login.user, password: login.password,
                         channel: channel, quality: subtype == 0 ? .main : .substream).url
    }
}
