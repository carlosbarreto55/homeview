import XCTest
@testable import IntelbrasViewer

final class PanelPlacementTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 0, width: 1512, height: 944)
    private let panel = NSSize(width: 600, height: 426)

    func testTopLeftTouchesTheIconsBottomRight() {
        let icon = NSRect(x: 700, y: 944, width: 30, height: 24)
        let origin = MenuBarPanel.panelOrigin(panelSize: panel, iconFrame: icon, screenFrame: screen)
        XCTAssertEqual(origin.x, 730)
        XCTAssertEqual(origin.y + panel.height, 944, "top edge at the bottom of the icon")
    }

    func testStaysOnScreenNearTheRightEdge() {
        let icon = NSRect(x: 1300, y: 944, width: 30, height: 24)
        let origin = MenuBarPanel.panelOrigin(panelSize: panel, iconFrame: icon, screenFrame: screen)
        XCTAssertEqual(origin.x + panel.width, screen.maxX)
    }

    func testSecondScreenToTheRight() {
        let external = NSRect(x: 1512, y: 0, width: 2560, height: 1415)
        let icon = NSRect(x: 3000, y: 1415, width: 30, height: 24)
        let origin = MenuBarPanel.panelOrigin(panelSize: panel, iconFrame: icon, screenFrame: external)
        XCTAssertEqual(origin.x, 3030)
    }
}
