import AppKit
import AVFoundation
import KSPlayer
import os

/// `CameraPlayer` backed by KSPlayer's FFmpeg engine (`KSMEPlayer`).
@MainActor
final class KSCameraPlayer: CameraPlayer {
    let view = NSView()
    private(set) var state: CameraPlayerState = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    var onStateChange: ((CameraPlayerState) -> Void)?

    private var player: KSMEPlayer?
    private var logName = ""

    init() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
    }

    func start(url: URL) {
        stop()
        logName = Self.logDescription(of: url)
        let player = KSMEPlayer(url: url, options: Self.makeOptions())
        player.delegate = self
        if let video = player.view {
            video.frame = view.bounds
            video.autoresizingMask = [.width, .height]
            view.addSubview(video)
        }
        player.contentMode = .scaleToFill
        self.player = player
        state = .connecting
        Logger.player.info("start \(self.logName, privacy: .public)")
        player.prepareToPlay()
    }

    func stop() {
        guard let player else { return }
        Logger.player.info("stop \(self.logName, privacy: .public)")
        player.delegate = nil
        player.shutdown()
        player.view?.removeFromSuperview()
        self.player = nil
        state = .idle
    }

    func currentFrame() async -> CGImage? {
        await player?.thumbnailImageAtCurrentTime()
    }

    private static func makeOptions() -> KSOptions {
        let options = KSOptions()
        options.formatContextOptions["rtsp_transport"] = "tcp"
        // Socket timeout in microseconds, so a dead DVR fails instead of hanging.
        options.formatContextOptions["timeout"] = 5_000_000
        options.hardwareDecode = true
        options.nobuffer = true
        options.codecLowDelay = true
        options.preferredForwardBufferDuration = 0.5
        options.maxAnalyzeDuration = 1_000_000
        options.probesize = 512 * 1024
        options.registerRemoteControll = false
        options.isLoopPlay = false
        return options
    }

    /// The stream address without user and password, safe to log.
    static func logDescription(of url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "<stream>"
        }
        components.user = nil
        components.password = nil
        return components.string ?? "<stream>"
    }
}

extension KSCameraPlayer: MediaPlayerDelegate {
    func readyToPlay(player: some MediaPlayerProtocol) {
        let video = player.tracks(mediaType: .video).first { $0.isEnabled }
        let size = player.naturalSize
        Logger.player.info("""
            ready \(self.logName, privacy: .public) \
            codec=\(video?.description ?? "?", privacy: .public) \
            size=\(Int(size.width))x\(Int(size.height)) \
            fps=\(player.nominalFrameRate)
            """)
        player.isMuted = true
        player.play()
        state = .playing
    }

    func changeLoadState(player: some MediaPlayerProtocol) {}

    func changeBuffering(player: some MediaPlayerProtocol, progress: Int) {}

    func playBack(player: some MediaPlayerProtocol, loopCount: Int) {}

    func finish(player: some MediaPlayerProtocol, error: Error?) {
        let reason = error.map { String(describing: $0) } ?? "stream ended"
        Logger.player.error("finish \(self.logName, privacy: .public) \(reason, privacy: .public)")
        state = .failed(reason: reason)
    }
}
