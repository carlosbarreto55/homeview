import XCTest
@testable import HomeView

final class SnapshotFileNameTests: XCTestCase {
    private let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!

    /// 13 October 2026, 21:04:37 in São Paulo.
    private var moment: Date {
        var components = DateComponents()
        (components.year, components.month, components.day) = (2026, 10, 13)
        (components.hour, components.minute, components.second) = (21, 4, 37)
        components.timeZone = saoPaulo
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testNameAndMoment() {
        XCTAssertEqual(SnapshotFileName.make(cameraName: "Garagem", date: moment, timeZone: saoPaulo),
                       "Garagem 2026-10-13 21.04.37.jpg")
    }

    func testSlashIsReplaced() {
        let name = SnapshotFileName.make(cameraName: "Sala/Cozinha", date: moment, timeZone: saoPaulo)
        XCTAssertTrue(name.hasPrefix("Sala-Cozinha "))
    }

    func testColonAndControlCharactersAreReplaced() {
        XCTAssertEqual(SnapshotFileName.sanitize("Frente: rua\tleste\n"), "Frente- rua-leste-")
    }

    func testAccentsAndSpacesAreKept() {
        XCTAssertEqual(SnapshotFileName.sanitize("Área de serviço"), "Área de serviço")
    }

    func testMainStreamBecomes1920x1080() {
        let size = SnapshotSize.output(forFrameWidth: 960, height: 1080)
        XCTAssertEqual(size.width, 1920)
        XCTAssertEqual(size.height, 1080)
    }

    func testWidescreenStreamIsUnchanged() {
        let size = SnapshotSize.output(forFrameWidth: 1280, height: 720)
        XCTAssertEqual(size.width, 1280)
        XCTAssertEqual(size.height, 720)
    }
}
