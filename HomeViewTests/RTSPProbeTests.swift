import XCTest
@testable import HomeView

/// A scripted `RTSPConnection`: each step answers one call.
private final class FakeConnection: RTSPConnection, @unchecked Sendable {
    enum Step {
        case succeed
        case respond(RTSPResponse)
        case fail(RTSPConnectionError)
        /// Never answers until `close()`.
        case hang
    }

    var isLocalNetworkDenied = false
    private var openStep: Step
    private var sendSteps: [Step]
    private(set) var requests: [String] = []
    private(set) var isClosed = false
    private var pending: (() -> Void)?
    private let lock = NSLock()

    init(open: Step = .succeed, sends: [Step] = []) {
        openStep = open
        sendSteps = sends
    }

    func open() async throws {
        try await perform(openStep).map { _ in () }.get()
    }

    func send(_ request: String) async throws -> RTSPResponse {
        lock.withLock { requests.append(request) }
        let step = lock.withLock { sendSteps.isEmpty ? Step.fail(.closed) : sendSteps.removeFirst() }
        guard let response = try await perform(step).get() else { throw RTSPConnectionError.invalidResponse }
        return response
    }

    func close() {
        let resume = lock.withLock { () -> (() -> Void)? in
            isClosed = true
            defer { pending = nil }
            return pending
        }
        resume?()
    }

    private func perform(_ step: Step) async -> Result<RTSPResponse?, Error> {
        switch step {
        case .succeed: return .success(nil)
        case .respond(let response): return .success(response)
        case .fail(let error): return .failure(error)
        case .hang:
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let closed = lock.withLock { () -> Bool in
                    if isClosed { return true }
                    pending = { continuation.resume() }
                    return false
                }
                if closed { continuation.resume() }
            }
            return .failure(RTSPConnectionError.closed)
        }
    }
}

private func response(_ status: Int, _ headers: [(String, String)] = []) -> RTSPResponse {
    RTSPResponse(statusCode: status,
                 headers: headers.map { RTSPResponse.Header(name: $0.0, value: $0.1) },
                 body: Data())
}

private let dvrChallenge = response(401, [
    ("WWW-Authenticate", #"Digest realm="Login to c496c9f4", nonce="4d3238b58b88196c""#),
])

final class RTSPProbeTests: XCTestCase {
    private func probe(_ connections: FakeConnection..., timeout: Duration = .seconds(5)) -> RTSPProbe {
        var queue = connections
        return RTSPProbe(makeConnection: { _, _ in queue.removeFirst() }, timeout: timeout)
    }

    private func check(_ probe: RTSPProbe) async -> RTSPProbe.Result {
        await probe.check(host: "192.168.1.2", port: 554, user: "macApp", password: "a@b:c")
    }

    func testAcceptedCredentials() async {
        let connection = FakeConnection(sends: [.respond(dvrChallenge), .respond(response(200))])
        let result = await check(probe(connection))
        XCTAssertEqual(result, .ok)
        XCTAssertTrue(connection.isClosed)

        XCTAssertEqual(connection.requests.count, 2)
        let uri = "rtsp://192.168.1.2:554/cam/realmonitor?channel=1&subtype=1"
        XCTAssertTrue(connection.requests[0].hasPrefix("DESCRIBE \(uri) RTSP/1.0\r\nCSeq: 1\r\n"))
        XCTAssertFalse(connection.requests[0].contains("Authorization"))
        let expected = DigestAuth.response(
            challenge: .init(realm: "Login to c496c9f4", nonce: "4d3238b58b88196c"),
            method: "DESCRIBE", uri: uri, user: "macApp", password: "a@b:c", clientNonce: "")
        XCTAssertTrue(connection.requests[1].contains("CSeq: 2\r\n"))
        XCTAssertTrue(connection.requests[1].contains(#"username="macApp""#))
        XCTAssertTrue(connection.requests[1].contains(#"response="\#(expected)""#))
        XCTAssertFalse(connection.requests.joined().contains("a@b:c"), "the password is never sent")
    }

    func testChannelWithoutCameraStillProvesTheLogin() async {
        let connection = FakeConnection(sends: [.respond(dvrChallenge), .respond(response(404))])
        let result = await check(probe(connection))
        XCTAssertEqual(result, .ok)
    }

    func testWrongCredentials() async {
        let connection = FakeConnection(sends: [.respond(dvrChallenge), .respond(dvrChallenge)])
        let result = await check(probe(connection))
        XCTAssertEqual(result, .wrongCredentials)
        XCTAssertEqual(connection.requests.count, 2, "only one authenticated attempt")
    }

    func testConnectionRefusedIsNotFound() async {
        let result = await check(probe(FakeConnection(open: .fail(.refused))))
        XCTAssertEqual(result, .notFound)
    }

    func testNoAnswerTimesOutAsNotFound() async {
        let connection = FakeConnection(open: .hang)
        let started = ContinuousClock.now
        let result = await check(probe(connection, timeout: .milliseconds(200)))
        XCTAssertEqual(result, .notFound)
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(2))
        XCTAssertTrue(connection.isClosed)
    }

    func testServerThatStopsAnsweringTimesOut() async {
        let connection = FakeConnection(sends: [.respond(dvrChallenge), .hang])
        // A second connection would crash the probe's factory: none may be made.
        let result = await check(probe(connection, timeout: .milliseconds(200)))
        XCTAssertEqual(result, .notFound)
    }

    func testLocalNetworkDeniedWhileWaiting() async {
        let connection = FakeConnection(open: .hang)
        connection.isLocalNetworkDenied = true
        let result = await check(probe(connection, timeout: .milliseconds(200)))
        XCTAssertEqual(result, .localNetworkDenied)
    }

    func testLocalNetworkDeniedError() async {
        let result = await check(probe(FakeConnection(open: .fail(.localNetworkDenied))))
        XCTAssertEqual(result, .localNetworkDenied)
    }

    func testReconnectsWhenTheServerClosesAfterTheChallenge() async {
        let first = FakeConnection(sends: [.respond(dvrChallenge), .fail(.closed)])
        let second = FakeConnection(sends: [.respond(response(200))])
        let result = await check(probe(first, second))
        XCTAssertEqual(result, .ok)
        XCTAssertEqual(second.requests.count, 1)
        XCTAssertTrue(second.requests[0].contains("Authorization: Digest"))
    }

    func testNoChallengeMeansNoLoginNeeded() async {
        let result = await check(probe(FakeConnection(sends: [.respond(response(200))])))
        XCTAssertEqual(result, .ok)
    }

    func testUnknownChallengeIsNotADVR() async {
        let connection = FakeConnection(sends: [.respond(response(401, [("WWW-Authenticate", "Bearer")]))])
        let result = await check(probe(connection))
        XCTAssertEqual(result, .notFound)
    }

    func testGarbageAnswerIsNotFound() async {
        let result = await check(probe(FakeConnection(sends: [.fail(.invalidResponse)])))
        XCTAssertEqual(result, .notFound)
    }
}

final class RTSPResponseTests: XCTestCase {
    func testWaitsForTheWholeHead() throws {
        let partial = Data("RTSP/1.0 401 Unauthorized\r\nCSeq: 1\r\n".utf8)
        var buffer = partial
        XCTAssertNil(try RTSPResponse.extract(from: &buffer))
        XCTAssertEqual(buffer, partial)
    }

    func testParsesStatusAndRepeatedHeaders() throws {
        var buffer = Data("""
            RTSP/1.0 401 Unauthorized\r
            CSeq: 1\r
            WWW-Authenticate: Digest realm="r", nonce="n"\r
            www-authenticate: Basic realm="r"\r
            \r

            """.utf8)
        let response = try XCTUnwrap(RTSPResponse.extract(from: &buffer))
        XCTAssertEqual(response.statusCode, 401)
        XCTAssertEqual(response.values(of: "WWW-Authenticate"),
                       [#"Digest realm="r", nonce="n""#, #"Basic realm="r""#])
        XCTAssertTrue(buffer.isEmpty)
    }

    func testReadsTheBodyAndKeepsWhatFollows() throws {
        var buffer = Data("RTSP/1.0 200 OK\r\nContent-Length: 5\r\n\r\nv=0\r\nRTSP/1.0".utf8)
        let response = try XCTUnwrap(RTSPResponse.extract(from: &buffer))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(String(data: response.body, encoding: .utf8), "v=0\r\n")
        XCTAssertEqual(String(data: buffer, encoding: .utf8), "RTSP/1.0")
    }

    func testWaitsForTheWholeBody() throws {
        var buffer = Data("RTSP/1.0 200 OK\r\nContent-Length: 50\r\n\r\nv=0".utf8)
        XCTAssertNil(try RTSPResponse.extract(from: &buffer))
    }

    func testRejectsSomethingElse() {
        var buffer = Data("HTTP/1.1 200 OK\r\n\r\n".utf8)
        XCTAssertThrowsError(try RTSPResponse.extract(from: &buffer))
    }
}
