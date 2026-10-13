import XCTest
@testable import HomeView

final class StreamURLTests: XCTestCase {
    private func make(
        channel: Int = 3, quality: StreamURL.Quality = .substream,
        user: String = "macApp", password: String = "secret"
    ) -> StreamURL {
        StreamURL(host: "192.168.1.2", port: 554, user: user, password: password,
                  channel: channel, quality: quality)
    }

    func testSubstreamOfChannel3() {
        let url = make().url
        XCTAssertEqual(url.scheme, "rtsp")
        XCTAssertEqual(url.host, "192.168.1.2")
        XCTAssertEqual(url.port, 554)
        XCTAssertEqual(url.path, "/cam/realmonitor")
        XCTAssertEqual(url.query, "channel=3&subtype=1")
        XCTAssertEqual(url.absoluteString,
                       "rtsp://macApp:secret@192.168.1.2:554/cam/realmonitor?channel=3&subtype=1")
    }

    func testMainStreamOfChannel3() {
        XCTAssertEqual(make(quality: .main).url.query, "channel=3&subtype=0")
    }

    func testPasswordWithSpecialCharactersIsPercentEncoded() {
        let url = make(password: "a@b:c/d#e").url
        XCTAssertEqual(url.absoluteString,
                       "rtsp://macApp:a%40b%3Ac%2Fd%23e@192.168.1.2:554/cam/realmonitor?channel=3&subtype=1")
        // The address still parses as the right host and decodes to the password.
        XCTAssertEqual(url.host, "192.168.1.2")
        XCTAssertEqual(url.port, 554)
        XCTAssertEqual(url.password(percentEncoded: false), "a@b:c/d#e")
        XCTAssertEqual(url.user(percentEncoded: false), "macApp")
    }

    func testUserKeepsItsCase() {
        XCTAssertEqual(make(user: "macApp").url.user(percentEncoded: false), "macApp")
    }

    func testNonASCIICredentialsAreEncodedAsUTF8() {
        let url = make(password: "senhaçã o").url
        XCTAssertTrue(url.absoluteString.contains(":senha%C3%A7%C3%A3%20o@"))
        XCTAssertEqual(url.password(percentEncoded: false), "senhaçã o")
    }

    func testLogDescriptionHasNoCredentials() {
        let stream = make(password: "a@b:c/d#e")
        XCTAssertEqual(stream.logDescription,
                       "rtsp://192.168.1.2:554/cam/realmonitor?channel=3&subtype=1")
        XCTAssertFalse(stream.logDescription.contains("macApp"))
        XCTAssertFalse(stream.logDescription.contains("a@b"))
    }
}
