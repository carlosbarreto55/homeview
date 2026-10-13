import XCTest
@testable import HomeView

final class CameraListStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.carloseduardo.HomeView.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func edited(_ store: CameraListStore, _ change: (inout [Camera]) -> Void) -> [Camera] {
        var draft = store.cameras
        change(&draft)
        return draft
    }

    func testEightDefaultCamerasAllVisible() {
        let store = CameraListStore(defaults: defaults)
        XCTAssertEqual(store.cameras.map(\.channel), Array(1...8))
        XCTAssertEqual(store.cameras.map(\.name), (1...8).map { "Canal \($0)" })
        XCTAssertTrue(store.cameras.allSatisfy(\.isVisible))
    }

    func testRenamingPersists() {
        let store = CameraListStore(defaults: defaults)
        store.apply(edited(store) { $0[2].name = "Garagem" })
        XCTAssertEqual(store.camera(channel: 3)?.name, "Garagem")
        XCTAssertEqual(CameraListStore(defaults: defaults).camera(channel: 3)?.name, "Garagem")
    }

    func testClearedNameGoesBackToDefault() {
        let store = CameraListStore(defaults: defaults)
        store.apply(edited(store) { $0[2].name = "Garagem" })
        store.apply(edited(store) { $0[2].name = "" })
        XCTAssertEqual(store.camera(channel: 3)?.name, "Canal 3")
        store.apply(edited(store) { $0[2].name = "   \n " })
        XCTAssertEqual(store.camera(channel: 3)?.name, "Canal 3")
    }

    func testNamesAreTrimmedAndLimitedTo30Characters() {
        XCTAssertEqual(CameraListStore.normalizedName("  Sala  ", channel: 1), "Sala")
        let long = String(repeating: "a", count: 40)
        XCTAssertEqual(CameraListStore.normalizedName(long, channel: 1).count, 30)
        // Cut at 30, then no trailing space left over.
        let spaced = String(repeating: "b", count: 29) + " cde"
        XCTAssertEqual(CameraListStore.normalizedName(spaced, channel: 1), String(repeating: "b", count: 29))
        XCTAssertEqual(CameraListStore.normalizedName("Câmera da área ✓", channel: 1), "Câmera da área ✓")
    }

    func testHidingPersistsAndFiltersVisibleCameras() {
        let store = CameraListStore(defaults: defaults)
        store.apply(edited(store) { cameras in
            for index in 4..<8 { cameras[index].isVisible = false }
        })
        XCTAssertEqual(store.visibleCameras.map(\.channel), [1, 2, 3, 4])
        XCTAssertEqual(CameraListStore(defaults: defaults).visibleCameras.map(\.channel), [1, 2, 3, 4])
    }

    func testEverythingHidden() {
        let store = CameraListStore(defaults: defaults)
        store.apply(edited(store) { cameras in
            for index in cameras.indices { cameras[index].isVisible = false }
        })
        XCTAssertTrue(store.visibleCameras.isEmpty)
    }

    func testChannelNumbersCannotBeChanged() {
        let store = CameraListStore(defaults: defaults)
        store.apply([Camera(channel: 9, name: "Extra", isVisible: true)])
        XCTAssertEqual(store.cameras.map(\.channel), Array(1...8))
    }

    func testDamagedSavedDataFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: "cameras")
        XCTAssertEqual(CameraListStore(defaults: defaults).cameras.map(\.name), (1...8).map { "Canal \($0)" })
    }
}
