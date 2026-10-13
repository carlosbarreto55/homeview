import Foundation
import Observation
import os

/// Runs one tile's stream: starts its player, and when the stream fails,
/// tries again on the `RetryPolicy`'s schedule.
@MainActor
@Observable
final class StreamSession: Identifiable {
    enum State: Equatable {
        case stopped
        case connecting
        case playing
        /// `nextRetry` is `nil` while retrying is suspended.
        case failed(nextRetry: Date?)
    }

    let channel: Int
    let stream: StreamURL
    @ObservationIgnored let player: CameraPlayer
    private(set) var state: State = .stopped {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    @ObservationIgnored var onStateChange: ((State) -> Void)?

    @ObservationIgnored private var retryPolicy: RetryPolicy
    @ObservationIgnored private let scheduler: RetryScheduler
    @ObservationIgnored private var pendingRetry: RetryTimer?
    @ObservationIgnored private(set) var isRetrySuspended = false

    var id: Int { channel }

    init(stream: StreamURL, player: CameraPlayer,
         retryPolicy: RetryPolicy = RetryPolicy(), scheduler: RetryScheduler? = nil) {
        channel = stream.channel
        self.stream = stream
        self.player = player
        self.retryPolicy = retryPolicy
        self.scheduler = scheduler ?? TaskRetryScheduler()
        player.onStateChange = { [weak self] state in
            self?.playerChanged(to: state)
        }
    }

    func start() {
        cancelRetry()
        state = .connecting
        player.start(url: stream.url)
    }

    func stop() {
        cancelRetry()
        player.stop()
        state = .stopped
    }

    /// Refresh: restarts right away with the shortest wait, and resumes
    /// retrying if it was suspended.
    func restart() {
        isRetrySuspended = false
        retryPolicy.reset()
        player.stop()
        start()
    }

    /// Stops retrying (the DVR rejected the login: retrying would lock the user).
    func suspendRetries() {
        isRetrySuspended = true
        cancelRetry()
        if case .failed = state {
            state = .failed(nextRetry: nil)
        }
    }

    private func playerChanged(to playerState: CameraPlayerState) {
        switch playerState {
        case .playing:
            retryPolicy.reset()
            state = .playing
        case .failed:
            guard state != .stopped else { return }
            scheduleRetry()
        case .connecting, .idle:
            break
        }
    }

    private func scheduleRetry() {
        cancelRetry()
        guard !isRetrySuspended else {
            state = .failed(nextRetry: nil)
            return
        }
        let retry = retryPolicy.failed()
        state = .failed(nextRetry: retry)
        Logger.player.info("""
            retry \(self.stream.logDescription, privacy: .public) at \
            \(retry.formatted(date: .omitted, time: .standard), privacy: .public)
            """)
        pendingRetry = scheduler.schedule(at: retry) { [weak self] in
            guard let self, case .failed = self.state else { return }
            self.start()
        }
    }

    private func cancelRetry() {
        pendingRetry?.cancel()
        pendingRetry = nil
    }
}

struct RetryTimer {
    let cancel: () -> Void
}

/// Runs an action at a given time; injectable so tests control time.
@MainActor
protocol RetryScheduler {
    func schedule(at date: Date, _ action: @escaping @MainActor () -> Void) -> RetryTimer
}

struct TaskRetryScheduler: RetryScheduler {
    func schedule(at date: Date, _ action: @escaping @MainActor () -> Void) -> RetryTimer {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0, date.timeIntervalSinceNow)))
            if !Task.isCancelled { action() }
        }
        return RetryTimer { task.cancel() }
    }
}
