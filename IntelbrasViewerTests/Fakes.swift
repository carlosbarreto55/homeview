import AppKit
@testable import IntelbrasViewer

@MainActor
final class FakeCameraPlayer: CameraPlayer {
    let view = NSView()
    private(set) var state: CameraPlayerState = .idle
    var onStateChange: ((CameraPlayerState) -> Void)?
    private(set) var startedURLs: [URL] = []
    private(set) var stopCount = 0
    var frame: CGImage?

    func start(url: URL) {
        startedURLs.append(url)
        emit(.connecting)
    }

    func stop() {
        stopCount += 1
        state = .idle
    }

    func currentFrame() async -> CGImage? {
        frame
    }

    /// Simulates the player changing state.
    func emit(_ newState: CameraPlayerState) {
        state = newState
        onStateChange?(newState)
    }
}

/// Collects scheduled actions; tests run them with `fire()`.
@MainActor
final class FakeRetryScheduler: RetryScheduler {
    struct Entry {
        let date: Date
        let action: @MainActor () -> Void
        var isCancelled: Bool
    }

    private(set) var entries: [Entry] = []

    var pendingDates: [Date] {
        entries.filter { !$0.isCancelled }.map(\.date)
    }

    func schedule(at date: Date, _ action: @escaping @MainActor () -> Void) -> RetryTimer {
        entries.append(Entry(date: date, action: action, isCancelled: false))
        let index = entries.count - 1
        return RetryTimer { [weak self] in self?.entries[index].isCancelled = true }
    }

    /// Runs every pending action, as if their time had come.
    func fire() {
        let due = entries.indices.filter { !entries[$0].isCancelled }
        for index in due {
            entries[index].isCancelled = true
            entries[index].action()
        }
    }
}
