import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import os

/// Spike only: with `-spikeFrameDump /path/name`, saves the player's current
/// frame as `name-raw.png` (stream pixels) and `name-16x9.png` (stretched to
/// 16:9 at the stream's height, as the panel draws it).
enum SpikeFrameDump {
    static var basePath: String? {
        UserDefaults.standard.string(forKey: "spikeFrameDump")
    }

    @MainActor
    static func dump(from player: CameraPlayer, to basePath: String) async {
        guard let frame = await player.currentFrame() else {
            Logger.player.error("frame dump: no frame")
            return
        }
        let height = frame.height
        let width = Int((Double(height) * 16 / 9).rounded())
        write(frame, to: basePath + "-raw.png")
        if let stretched = redraw(frame, width: width, height: height) {
            write(stretched, to: basePath + "-16x9.png")
        }
        Logger.player.info("frame dump: raw \(frame.width)x\(frame.height), 16:9 \(width)x\(height)")
    }

    private static func redraw(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func write(_ image: CGImage, to path: String) {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
