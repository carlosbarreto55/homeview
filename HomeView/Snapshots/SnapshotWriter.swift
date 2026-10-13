import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import os

/// Saves the frame a camera is showing as a JPEG, at 16:9, in the snapshots folder.
struct SnapshotWriter {
    enum Failure: Error, Equatable {
        case noFrame
        case drawFailed
        case writeFailed
    }

    var folder = SnapshotFolder.url
    var now: () -> Date = Date.init
    var timeZone = TimeZone.current

    @MainActor
    func save(from player: CameraPlayer, cameraName: String) async -> Result<URL, Failure> {
        guard let frame = await player.currentFrame() else { return .failure(.noFrame) }
        let date = now()
        return await Task.detached { [self] in
            write(frame, cameraName: cameraName, date: date)
        }.value
    }

    func write(_ frame: CGImage, cameraName: String, date: Date) -> Result<URL, Failure> {
        guard let image = Self.redrawAt16By9(frame) else { return .failure(.drawFailed) }
        do {
            try SnapshotFolder.create(at: folder)
        } catch {
            Logger.panel.error("snapshot folder: \(error.localizedDescription, privacy: .public)")
            return .failure(.writeFailed)
        }
        let url = availableURL(for: SnapshotFileName.make(cameraName: cameraName, date: date, timeZone: timeZone))
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { return .failure(.writeFailed) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            Logger.panel.error("snapshot: could not write the JPEG")
            return .failure(.writeFailed)
        }
        return .success(url)
    }

    /// Stretches the frame to 16:9 at its own height, as the panel shows it.
    static func redrawAt16By9(_ frame: CGImage) -> CGImage? {
        let size = SnapshotSize.output(forFrameWidth: frame.width, height: frame.height)
        guard let context = CGContext(
            data: nil, width: size.width, height: size.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(frame, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return context.makeImage()
    }

    /// The file name, or "name 2.jpg", "name 3.jpg"… when taken within the same second.
    private func availableURL(for fileName: String) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        var url = folder.appending(path: fileName)
        var copy = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appending(path: "\(base) \(copy).jpg")
            copy += 1
        }
        return url
    }
}
