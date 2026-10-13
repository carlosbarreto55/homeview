import Foundation

/// When a failed stream tries again: after 5 s, then doubling up to 30 s,
/// back to 5 s after a success.
struct RetryPolicy {
    static let initialDelay: TimeInterval = 5
    static let maxDelay: TimeInterval = 30

    private(set) var nextDelay = RetryPolicy.initialDelay
    var now: () -> Date = Date.init

    /// Records a failure and returns when to try again.
    mutating func failed() -> Date {
        let retry = now().addingTimeInterval(nextDelay)
        nextDelay = min(nextDelay * 2, Self.maxDelay)
        return retry
    }

    /// Records a success (or a manual refresh): the next wait is 5 s again.
    mutating func reset() {
        nextDelay = Self.initialDelay
    }
}
