import XCTest
@testable import IntelbrasViewer

final class DVRSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: DVRSettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "com.carloseduardo.IntelbrasViewer.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = DVRSettingsStore(defaults: defaults, keychain: KeychainStore(service: suiteName))
    }

    override func tearDown() {
        try? store.forget()
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let settings = DVRSettings(host: "192.168.1.20", port: 8554,
                                       credentials: Credentials(user: "macApp", password: "a@b:c/d#e"))

    func testNothingSavedMeansSetup() throws {
        XCTAssertNil(try store.load())
    }

    func testSetupIsPrefilledWithTheDefaults() {
        XCTAssertEqual(store.savedAddress.host, "192.168.1.2")
        XCTAssertEqual(store.savedAddress.port, 554)
    }

    func testSaveThenLoad() throws {
        try store.save(settings)
        XCTAssertEqual(try store.load(), settings)
    }

    func testSettingsSurviveANewStore() throws {
        try store.save(settings)
        let reopened = DVRSettingsStore(defaults: UserDefaults(suiteName: suiteName)!,
                                        keychain: KeychainStore(service: suiteName))
        XCTAssertEqual(try reopened.load(), settings)
    }

    func testPasswordStaysOutOfPreferences() throws {
        try store.save(settings)
        let saved = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertEqual(Set(saved.keys), ["dvr.host", "dvr.port"])
        for value in saved.values {
            XCTAssertFalse("\(value)".contains("a@b:c/d#e"))
            XCTAssertFalse("\(value)".contains("macApp"))
        }
    }

    func testForgetRemovesLoginAndAddress() throws {
        try store.save(settings)
        try store.forget()
        XCTAssertNil(try store.load())
        XCTAssertEqual(store.savedAddress.host, DVRSettings.defaultHost)
        XCTAssertEqual(store.savedAddress.port, DVRSettings.defaultPort)
    }

    func testStreamURLUsesTheSettings() {
        let url = settings.streamURL(channel: 2, quality: .main)
        XCTAssertEqual(url.logDescription, "rtsp://192.168.1.20:8554/cam/realmonitor?channel=2&subtype=0")
        XCTAssertEqual(url.url.password(percentEncoded: false), "a@b:c/d#e")
    }
}
