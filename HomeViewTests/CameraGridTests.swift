import XCTest
@testable import HomeView

final class CameraGridTests: XCTestCase {
    func testEightCamerasScrollPast540Points() {
        XCTAssertGreaterThan(CameraGridView.contentHeight(count: 8), CameraGridView.maxHeight)
    }

    func testSixCamerasFitWithoutScrolling() {
        XCTAssertLessThanOrEqual(CameraGridView.contentHeight(count: 6), CameraGridView.maxHeight)
    }

    func testTilesAre16By9InTwoColumns() {
        // One row: two 282 x 158.625 pt tiles, plus 12 pt padding above and below.
        XCTAssertEqual(CameraGridView.contentHeight(count: 2), 282 * 9 / 16 + 24, accuracy: 0.001)
        XCTAssertEqual(CameraGridView.contentHeight(count: 1), CameraGridView.contentHeight(count: 2))
    }

    func testTileStates() {
        XCTAssertEqual(TileState(session: .connecting, isVerifying: false), .connecting)
        XCTAssertEqual(TileState(session: .playing, isVerifying: false), .playing)
        XCTAssertEqual(TileState(session: .failed(nextRetry: Date()), isVerifying: false), .noSignal)
        XCTAssertEqual(TileState(session: .failed(nextRetry: nil), isVerifying: false), .noSignal)
        XCTAssertEqual(TileState(session: nil, isVerifying: true), .connecting)
        XCTAssertEqual(TileState(session: nil, isVerifying: false), .noSignal)
    }
}
