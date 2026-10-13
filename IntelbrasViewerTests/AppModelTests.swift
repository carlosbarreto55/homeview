import XCTest
@testable import IntelbrasViewer

@MainActor
final class AppModelTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settingsStore: DVRSettingsStore!
    private var players: [FakeCameraPlayer] = []
    private var probeResult = RTSPProbe.Result.ok
    private var probeCount = 0

    private let settings = DVRSettings(host: "192.168.1.2", port: 554,
                                       credentials: Credentials(user: "macApp", password: "secret"))

    override func setUp() async throws {
        suiteName = "com.carloseduardo.IntelbrasViewer.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settingsStore = DVRSettingsStore(defaults: defaults, keychain: KeychainStore(service: suiteName))
        players = []
        probeResult = .ok
        probeCount = 0
    }

    override func tearDown() async throws {
        try? settingsStore.forget()
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(configured: Bool = true) throws -> AppModel {
        if configured { try settingsStore.save(settings) }
        return AppModel(
            settingsStore: settingsStore,
            cameras: CameraListStore(defaults: defaults),
            probe: { [unowned self] _ in
                probeCount += 1
                return probeResult
            },
            makePlayer: { [unowned self] in
                let player = FakeCameraPlayer()
                players.append(player)
                return player
            })
    }

    private func open(_ model: AppModel) async {
        model.panelVisibilityChanged(true)
        await model.settle()
    }

    private func startedQueries() -> [String?] {
        players.compactMap { $0.startedURLs.last?.query }
    }

    func testFirstRunShowsSetupAndStreamsNothing() async throws {
        let model = try makeModel(configured: false)
        await open(model)
        XCTAssertEqual(model.route, .setup)
        XCTAssertTrue(model.sessions.isEmpty)
        XCTAssertEqual(probeCount, 0)
    }

    func testOpeningThePanelChecksTheLoginOnceThenStreamsTheGrid() async throws {
        let model = try makeModel()
        await open(model)
        XCTAssertEqual(model.route, .grid)
        XCTAssertEqual(probeCount, 1)
        XCTAssertEqual(model.sessions.map(\.channel), Array(1...8))
        XCTAssertEqual(startedQueries(), (1...8).map { "channel=\($0)&subtype=1" })
        XCTAssertEqual(model.status, .connecting)

        players[0].emit(.playing)
        XCTAssertEqual(model.status, .connected)
    }

    func testHiddenCamerasAreNotStreamed() async throws {
        let model = try makeModel()
        var cameras = model.cameras.cameras
        cameras[6].isVisible = false
        cameras[7].isVisible = false
        model.cameras.apply(cameras)
        await open(model)
        XCTAssertEqual(model.sessions.map(\.channel), Array(1...6))
    }

    func testClosingThePanelStopsEveryStream() async throws {
        let model = try makeModel()
        await open(model)
        model.panelVisibilityChanged(false)
        XCTAssertTrue(model.sessions.isEmpty)
        XCTAssertTrue(players.allSatisfy { $0.stopCount == 1 })
        XCTAssertEqual(model.status, .idle)
    }

    func testRepeatedVisibilityReportsAreIgnored() async throws {
        let model = try makeModel()
        await open(model)
        model.panelVisibilityChanged(true)
        await model.settle()
        XCTAssertEqual(players.count, 8)
    }

    func testEnlargingStopsTheGridAndPlaysTheMainStream() async throws {
        let model = try makeModel()
        await open(model)
        model.openCamera(channel: 6)
        XCTAssertEqual(model.route, .enlarged(channel: 6))
        XCTAssertTrue(players.prefix(8).allSatisfy { $0.stopCount == 1 })
        XCTAssertEqual(model.sessions.map(\.channel), [6])
        XCTAssertEqual(players.last?.startedURLs.last?.query, "channel=6&subtype=0")
        XCTAssertEqual(probeCount, 1, "no new login check when switching views")

        model.backToGrid()
        XCTAssertEqual(model.route, .grid)
        XCTAssertEqual(model.sessions.count, 8)
    }

    func testReopeningShowsTheEnlargedCameraAgain() async throws {
        let model = try makeModel()
        await open(model)
        model.openCamera(channel: 2)
        model.panelVisibilityChanged(false)
        await open(model)
        XCTAssertEqual(model.route, .enlarged(channel: 2))
        XCTAssertEqual(model.sessions.map(\.channel), [2])
        XCTAssertEqual(players.last?.startedURLs.last?.query, "channel=2&subtype=0")
    }

    func testRejectedLoginStartsNoStreams() async throws {
        probeResult = .wrongCredentials
        let model = try makeModel()
        await open(model)
        XCTAssertTrue(model.sessions.isEmpty)
        XCTAssertTrue(players.isEmpty, "no stream may log in with a rejected password")
        XCTAssertEqual(model.status, .wrongCredentials)
    }

    func testUnreachableDVRStillStartsStreamsSoTheyRetry() async throws {
        probeResult = .notFound
        let model = try makeModel()
        await open(model)
        XCTAssertEqual(model.sessions.count, 8)
    }

    func testEveryStreamFailingAsksTheProbeOnce() async throws {
        let model = try makeModel()
        await open(model)
        probeResult = .notFound
        players.forEach { $0.emit(.failed(reason: "gone")) }
        await model.settle()
        XCTAssertEqual(probeCount, 2)
        XCTAssertEqual(model.status, .unreachable)

        players.forEach { $0.emit(.failed(reason: "gone")) }
        await model.settle()
        XCTAssertEqual(probeCount, 2, "not again until a stream plays")
    }

    func testRejectedLoginWhileStreamingStopsRetries() async throws {
        let model = try makeModel()
        await open(model)
        probeResult = .wrongCredentials
        players.forEach { $0.emit(.failed(reason: "401")) }
        await model.settle()
        XCTAssertEqual(model.status, .wrongCredentials)
        XCTAssertTrue(model.sessions.allSatisfy { $0.state == .failed(nextRetry: nil) })
    }

    func testRefreshRestartsEveryStream() async throws {
        let model = try makeModel()
        await open(model)
        players[3].emit(.failed(reason: "unplugged"))
        model.refresh()
        XCTAssertTrue(model.sessions.allSatisfy { $0.state == .connecting })
        XCTAssertEqual(players.count, 8, "same players, restarted")
        XCTAssertTrue(players.allSatisfy { $0.startedURLs.count == 2 })
    }

    func testRefreshAfterARejectedLoginChecksAgain() async throws {
        probeResult = .wrongCredentials
        let model = try makeModel()
        await open(model)
        probeResult = .ok
        model.refresh()
        await model.settle()
        XCTAssertEqual(model.sessions.count, 8)
    }

    func testFormsStopStreamsAndCancelGoesBack() async throws {
        let model = try makeModel()
        await open(model)
        model.openCamera(channel: 3)
        model.openDVRSettings()
        XCTAssertEqual(model.route, .dvrSettings)
        XCTAssertTrue(model.sessions.isEmpty)
        model.closeForm()
        XCTAssertEqual(model.route, .enlarged(channel: 3))
        XCTAssertEqual(model.sessions.map(\.channel), [3])
    }

    func testClosingAFormOnAHiddenCameraGoesToTheGrid() async throws {
        let model = try makeModel()
        await open(model)
        model.openCamera(channel: 3)
        model.openRenameCameras()
        var cameras = model.cameras.cameras
        cameras[2].isVisible = false
        model.cameras.apply(cameras)
        model.closeForm()
        XCTAssertEqual(model.route, .grid)
    }
}
