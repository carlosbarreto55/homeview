import XCTest
@testable import HomeView

final class DigestAuthTests: XCTestCase {
    // RFC 2617, section 3.5.
    private let rfcHeader = #"""
        Digest realm="testrealm@host.com", qop="auth,auth-int", \#
        nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"
        """#

    func testParsesTheRFCChallenge() throws {
        let challenge = try XCTUnwrap(DigestAuth.Challenge(header: rfcHeader))
        XCTAssertEqual(challenge.realm, "testrealm@host.com")
        XCTAssertEqual(challenge.nonce, "dcd98b7102dd2f0e8b11d0f600bfb0c093")
        XCTAssertEqual(challenge.qop, "auth")
        XCTAssertEqual(challenge.opaque, "5ccc069c403ebaf9f0171e9517f40e41")
    }

    func testRFCExampleResponseWithQop() throws {
        let challenge = try XCTUnwrap(DigestAuth.Challenge(header: rfcHeader))
        let response = DigestAuth.response(
            challenge: challenge, method: "GET", uri: "/dir/index.html",
            user: "Mufasa", password: "Circle Of Life", nonceCount: 1, clientNonce: "0a4f113b")
        XCTAssertEqual(response, "6629fae49393a05397450978507c4ef1")
    }

    func testRFCExampleResponseWithoutQop() {
        let challenge = DigestAuth.Challenge(realm: "testrealm@host.com",
                                             nonce: "dcd98b7102dd2f0e8b11d0f600bfb0c093")
        let response = DigestAuth.response(
            challenge: challenge, method: "GET", uri: "/dir/index.html",
            user: "Mufasa", password: "Circle Of Life", clientNonce: "unused")
        XCTAssertEqual(response, "670fd8c2df070c60b045671b8b24ff02")
    }

    func testParsesTheDVRChallenge() throws {
        let header = #"Digest realm="Login to c496c9f4bea333364eb1854b83dfcb34", nonce="4d3238b58b88196cfad2c29cacf0d1f5""#
        let challenge = try XCTUnwrap(DigestAuth.Challenge(header: header))
        XCTAssertEqual(challenge.realm, "Login to c496c9f4bea333364eb1854b83dfcb34")
        XCTAssertEqual(challenge.nonce, "4d3238b58b88196cfad2c29cacf0d1f5")
        XCTAssertNil(challenge.qop)
        XCTAssertNil(challenge.opaque)
    }

    func testIgnoresNonDigestOrIncompleteChallenges() {
        XCTAssertNil(DigestAuth.Challenge(header: #"Basic realm="x""#))
        XCTAssertNil(DigestAuth.Challenge(header: #"Digest nonce="abc""#))
    }

    func testParsesUnquotedValuesAndCommasInsideQuotes() {
        let parameters = DigestAuth.parseParameters(#"realm="a, b", algorithm=MD5, stale=FALSE"#)
        XCTAssertEqual(parameters["realm"], "a, b")
        XCTAssertEqual(parameters["algorithm"], "MD5")
        XCTAssertEqual(parameters["stale"], "FALSE")
    }

    func testAuthorizationHeaderWithoutQop() {
        let challenge = DigestAuth.Challenge(realm: "testrealm@host.com",
                                             nonce: "dcd98b7102dd2f0e8b11d0f600bfb0c093")
        let header = DigestAuth.authorization(
            challenge: challenge, method: "GET", uri: "/dir/index.html",
            user: "Mufasa", password: "Circle Of Life", clientNonce: "unused")
        XCTAssertEqual(header, #"""
            Digest username="Mufasa", realm="testrealm@host.com", \#
            nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", uri="/dir/index.html", \#
            response="670fd8c2df070c60b045671b8b24ff02"
            """#)
    }

    func testAuthorizationHeaderWithQop() throws {
        let challenge = try XCTUnwrap(DigestAuth.Challenge(header: rfcHeader))
        let header = DigestAuth.authorization(
            challenge: challenge, method: "GET", uri: "/dir/index.html",
            user: "Mufasa", password: "Circle Of Life", nonceCount: 1, clientNonce: "0a4f113b")
        XCTAssertTrue(header.contains(#"response="6629fae49393a05397450978507c4ef1""#))
        XCTAssertTrue(header.contains("qop=auth, nc=00000001, cnonce=\"0a4f113b\""))
        XCTAssertTrue(header.contains(#"opaque="5ccc069c403ebaf9f0171e9517f40e41""#))
    }
}
