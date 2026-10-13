import XCTest
@testable import IntelbrasViewer

@MainActor
final class StreamSessionTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000)
    private var player: FakeCameraPlayer!
    private var scheduler: FakeRetryScheduler!
    private var session: StreamSession!

    override func setUp() async throws {
        player = FakeCameraPlayer()
        scheduler = FakeRetryScheduler()
        var policy = RetryPolicy()
        policy.now = { [now] in now }
        let stream = StreamURL(host: "192.168.1.2", port: 554, user: "macApp", password: "secret",
                               channel: 4, quality: .substream)
        session = StreamSession(stream: stream, player: player, retryPolicy: policy, scheduler: scheduler)
    }

    private func after(_ seconds: TimeInterval) -> Date {
        now.addingTimeInterval(seconds)
    }

    func testStartsTheStreamAndPlays() {
        XCTAssertEqual(session.state, .stopped)
        session.start()
        XCTAssertEqual(session.state, .connecting)
        XCTAssertEqual(player.startedURLs.first?.query, "channel=4&subtype=1")
        player.emit(.playing)
        XCTAssertEqual(session.state, .playing)
    }

    func testFailureWaitsThenRetries() {
        session.start()
        player.emit(.failed(reason: "gone"))
        XCTAssertEqual(session.state, .failed(nextRetry: after(5)))
        XCTAssertEqual(scheduler.pendingDates, [after(5)])
        XCTAssertEqual(player.startedURLs.count, 1)

        scheduler.fire()
        XCTAssertEqual(session.state, .connecting)
        XCTAssertEqual(player.startedURLs.count, 2)
    }

    func testRepeatedFailuresDoubleTheWaitUpTo30Seconds() {
        session.start()
        var retries: [Date?] = []
        for _ in 0..<5 {
            player.emit(.failed(reason: "gone"))
            if case .failed(let next) = session.state { retries.append(next) }
            scheduler.fire()
        }
        XCTAssertEqual(retries, [after(5), after(10), after(20), after(30), after(30)])
    }

    func testPlayingAgainResetsTheWait() {
        session.start()
        player.emit(.failed(reason: "gone"))
        scheduler.fire()
        player.emit(.failed(reason: "gone"))
        scheduler.fire()
        player.emit(.playing)
        player.emit(.failed(reason: "unplugged"))
        XCTAssertEqual(session.state, .failed(nextRetry: after(5)))
    }

    func testStopCancelsThePendingRetry() {
        session.start()
        player.emit(.failed(reason: "gone"))
        session.stop()
        XCTAssertEqual(session.state, .stopped)
        XCTAssertEqual(player.stopCount, 1)
        XCTAssertTrue(scheduler.pendingDates.isEmpty)
        scheduler.fire()
        XCTAssertEqual(player.startedURLs.count, 1, "no retry after stop")
    }

    func testFailureReportedAfterStopIsIgnored() {
        session.start()
        session.stop()
        player.emit(.failed(reason: "late"))
        XCTAssertEqual(session.state, .stopped)
        XCTAssertTrue(scheduler.pendingDates.isEmpty)
    }

    func testRestartRetriesRightAwayWithTheShortestWait() {
        session.start()
        for _ in 0..<4 {
            player.emit(.failed(reason: "gone"))
            scheduler.fire()
        }
        player.emit(.failed(reason: "gone"))
        XCTAssertEqual(session.state, .failed(nextRetry: after(30)))

        session.restart()
        XCTAssertEqual(session.state, .connecting)
        XCTAssertTrue(scheduler.pendingDates.isEmpty, "the 30 s wait is cancelled")
        player.emit(.failed(reason: "gone"))
        XCTAssertEqual(session.state, .failed(nextRetry: after(5)))
    }

    func testSuspendedSessionDoesNotRetryUntilRestarted() {
        session.start()
        player.emit(.failed(reason: "401"))
        session.suspendRetries()
        XCTAssertEqual(session.state, .failed(nextRetry: nil))
        XCTAssertTrue(scheduler.pendingDates.isEmpty)

        session.restart()
        XCTAssertEqual(session.state, .connecting)
        player.emit(.failed(reason: "gone"))
        XCTAssertEqual(session.state, .failed(nextRetry: after(5)))
    }

    func testSuspendedBeforeFailingStaysSuspended() {
        session.start()
        session.suspendRetries()
        player.emit(.failed(reason: "401"))
        XCTAssertEqual(session.state, .failed(nextRetry: nil))
        XCTAssertTrue(scheduler.pendingDates.isEmpty)
    }
}
