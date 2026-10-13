import SwiftUI
import XCTest
@testable import IntelbrasViewer

/// Renders panel screens to PNG files for looking at the layout without
/// opening the menu bar. Skipped unless `RENDER_PANEL_DIR` is set, e.g.
///
///     TEST_RUNNER_RENDER_PANEL_DIR=/tmp/panel make test
///
/// `ImageRenderer` cannot draw AppKit views (video, menus, borderless
/// buttons): they appear as placeholders. The grid is drawn without its
/// scroll view (`rendersStatically`).
@MainActor
final class PanelRenderTests: XCTestCase {
    private var directory: URL!
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settingsStore: DVRSettingsStore!
    private var players: [FakeCameraPlayer] = []
    private var probeResult = RTSPProbe.Result.ok

    override func setUp() async throws {
        guard let path = ProcessInfo.processInfo.environment["RENDER_PANEL_DIR"] else {
            throw XCTSkip("set RENDER_PANEL_DIR to render the panel")
        }
        directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = "com.carloseduardo.IntelbrasViewer.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settingsStore = DVRSettingsStore(defaults: defaults, keychain: KeychainStore(service: suiteName))
    }

    override func tearDown() async throws {
        try? settingsStore?.forget()
        if let suiteName { defaults.removePersistentDomain(forName: suiteName) }
    }

    private func makeModel(configured: Bool = true) async throws -> AppModel {
        if configured {
            try settingsStore.save(DVRSettings(host: "192.168.1.2", port: 554,
                                               credentials: Credentials(user: "macApp", password: "x")))
        }
        let model = AppModel(settingsStore: settingsStore, cameras: CameraListStore(defaults: defaults),
                             probe: { [unowned self] _ in probeResult },
                             loginItem: FakeLoginItem(),
                             makePlayer: { [unowned self] in
                                 let player = FakeCameraPlayer()
                                 players.append(player)
                                 return player
                             })
        model.panelVisibilityChanged(true)
        await model.settle()
        return model
    }

    private func render(_ model: AppModel, _ name: String) {
        let content = PanelView(model: model)
            .environment(\.rendersStatically, true)
            .background(Color(nsColor: .windowBackgroundColor))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return XCTFail("no image for \(name)") }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: directory.appending(path: "\(name).png"))
    }

    func testRenderGrid() async throws {
        let model = try await makeModel()
        var cameras = model.cameras.cameras
        cameras[2].name = "Garagem"
        model.cameras.apply(cameras)
        players.prefix(5).forEach { $0.emit(.playing) }
        players[5].emit(.failed(reason: "gone"))
        render(model, "grid")
    }

    func testRenderEmptyGrid() async throws {
        let model = try await makeModel()
        model.openRenameCameras()
        model.cameras.apply(model.cameras.cameras.map { var camera = $0; camera.isVisible = false; return camera })
        model.closeForm()
        render(model, "grid-empty")
    }

    func testRenderEnlarged() async throws {
        let model = try await makeModel()
        model.openCamera(channel: 2)
        render(model, "enlarged")
    }

    func testRenderWrongCredentials() async throws {
        probeResult = .wrongCredentials
        let model = try await makeModel()
        render(model, "wrong-credentials")
    }

    func testRenderRenameCameras() async throws {
        let model = try await makeModel()
        model.openRenameCameras()
        render(model, "rename")
    }

    func testRenderSetup() async throws {
        let model = try await makeModel(configured: false)
        render(model, "setup")
    }
}
