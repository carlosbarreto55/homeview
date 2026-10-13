import XCTest
@testable import IntelbrasViewer

final class RetryPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func makePolicy(now: @escaping () -> Date) -> RetryPolicy {
        var policy = RetryPolicy()
        policy.now = now
        return policy
    }

    func testWaitsDoubleUpTo30Seconds() {
        var policy = makePolicy { self.start }
        let waits = (0..<6).map { _ in policy.failed().timeIntervalSince(start) }
        XCTAssertEqual(waits, [5, 10, 20, 30, 30, 30])
    }

    func testRetryTimeCountsFromTheFailure() {
        var clock = start
        var policy = makePolicy { clock }
        XCTAssertEqual(policy.failed(), start.addingTimeInterval(5))
        clock = start.addingTimeInterval(7)
        XCTAssertEqual(policy.failed(), start.addingTimeInterval(17))
    }

    func testSuccessResetsTheWait() {
        var policy = makePolicy { self.start }
        _ = policy.failed()
        _ = policy.failed()
        _ = policy.failed()
        policy.reset()
        XCTAssertEqual(policy.failed(), start.addingTimeInterval(5))
    }
}
