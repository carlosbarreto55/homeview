import AppKit
import CoreGraphics

enum CameraPlayerState: Equatable {
    case idle
    case connecting
    case playing
    case failed(reason: String)
}

/// What the app needs from a video player. Only this file and the
/// implementation behind it know which library decodes the streams.
@MainActor
protocol CameraPlayer: AnyObject {
    /// The view the video is drawn into. Its picture is stretched to fill it.
    var view: NSView { get }
    var state: CameraPlayerState { get }
    var onStateChange: ((CameraPlayerState) -> Void)? { get set }

    func start(url: URL)
    func stop()
    /// The frame currently shown, at the stream's pixel size.
    func currentFrame() async -> CGImage?
}
