import XCTest
@testable import IntelbrasViewer

@MainActor
final class AppModelSnapshotTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settingsStore: DVRSettingsStore!
    private var folder: URL!
    private var players: [FakeCameraPlayer] = []

    override func setUp() async throws {
        suiteName = "com.carloseduardo.IntelbrasViewer.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settingsStore = DVRSettingsStore(defaults: defaults, keychain: KeychainStore(service: suiteName))
        try settingsStore.save(DVRSettings(host: "192.168.1.2", port: 554,
                                           credentials: Credentials(user: "macApp", password: "x")))
        folder = FileManager.default.temporaryDirectory.appending(path: "AppModelSnapshotTests-\(UUID().uuidString)")
        players = []
    }

    override func tearDown() async throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: folder)
        try? settingsStore.forget()
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeEnlargedModel(channel: Int = 3) async -> AppModel {
        let model = AppModel(
            settingsStore: settingsStore, cameras: CameraListStore(defaults: defaults),
            probe: { _ in .ok }, loginItem: FakeLoginItem(),
            snapshotWriter: SnapshotWriter(folder: folder),
            makePlayer: { [unowned self] in
                let player = FakeCameraPlayer()
                players.append(player)
                return player
            })
        model.snapshotMessageDuration = .milliseconds(50)
        model.panelVisibilityChanged(true)
        await model.settle()
        model.openCamera(channel: channel)
        return model
    }

    private var frame: CGImage {
        let context = CGContext(data: nil, width: 960, height: 1080, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        return context.makeImage()!
    }

    func testButtonDisabledUntilTheFirstFrame() async {
        let model = await makeEnlargedModel()
        XCTAssertFalse(model.canTakeSnapshot, "still connecting")
        players.last?.emit(.playing)
        players.last?.frame = frame
        await model.settle()
        XCTAssertTrue(model.canTakeSnapshot)
    }

    func testButtonDisabledAgainWhenTheStreamFails() async {
        let model = await makeEnlargedModel()
        players.last?.frame = frame
        players.last?.emit(.playing)
        await model.settle()
        players.last?.emit(.failed(reason: "gone"))
        XCTAssertFalse(model.canTakeSnapshot)
    }

    func testSnapshotOfARenamedCamera() async throws {
        let model = await makeEnlargedModel()
        var cameras = model.cameras.cameras
        cameras[2].name = "Garagem"
        model.cameras.apply(cameras)
        players.last?.frame = frame
        players.last?.emit(.playing)
        await model.settle()

        await model.takeSnapshot()
        XCTAssertEqual(model.snapshotMessage, .saved)
        XCTAssertEqual(model.snapshotMessage?.text, "Foto salva")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].hasPrefix("Garagem "))

        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(model.snapshotMessage, "the message goes away")
    }

    func testFailureKeepsTheCameraPlaying() async throws {
        let model = await makeEnlargedModel()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        players.last?.frame = frame
        players.last?.emit(.playing)
        await model.settle()

        await model.takeSnapshot()
        XCTAssertEqual(model.snapshotMessage?.text, "Não foi possível salvar a foto")
        XCTAssertEqual(model.sessions.first?.state, .playing)
        XCTAssertEqual(players.last?.stopCount, 0)
    }

    func testNoSnapshotFromTheGrid() async throws {
        let model = await makeEnlargedModel()
        model.backToGrid()
        await model.takeSnapshot()
        XCTAssertNil(model.snapshotMessage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }
}
