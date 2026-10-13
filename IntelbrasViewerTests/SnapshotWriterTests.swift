import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import IntelbrasViewer

final class SnapshotWriterTests: XCTestCase {
    private var root: URL!
    private var writer: SnapshotWriter!
    private let date = Date(timeIntervalSinceReferenceDate: 813_628_000)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "SnapshotWriterTests-\(UUID().uuidString)")
        writer = SnapshotWriter(folder: root.appending(path: "Intelbras Viewer"), timeZone: TimeZone(identifier: "UTC")!)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writer.folder.path)
        try? FileManager.default.removeItem(at: root)
    }

    private func frame(width: Int, height: Int) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func properties(of url: URL) throws -> (type: String, width: Int, height: Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (CGImageSourceGetType(source) as String? ?? "",
                properties[kCGImagePropertyPixelWidth] as? Int ?? 0,
                properties[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    func testWritesA1920x1080JPEGInANewFolder() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: writer.folder.path))
        let url = try writer.write(frame(width: 960, height: 1080), cameraName: "Garagem", date: date).get()
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, writer.folder.standardizedFileURL)
        XCTAssertEqual(url.lastPathComponent, "Garagem 2026-10-13 23.46.40.jpg")
        let image = try properties(of: url)
        XCTAssertEqual(image.type, UTType.jpeg.identifier)
        XCTAssertEqual(image.width, 1920)
        XCTAssertEqual(image.height, 1080)
    }

    func testSameSecondDoesNotOverwrite() throws {
        let first = try writer.write(frame(width: 1280, height: 720), cameraName: "Sala", date: date).get()
        let second = try writer.write(frame(width: 1280, height: 720), cameraName: "Sala", date: date).get()
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(second.lastPathComponent, "Sala 2026-10-13 23.46.40 2.jpg")
    }

    func testReadOnlyFolderFails() throws {
        try FileManager.default.createDirectory(at: writer.folder, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: writer.folder.path)
        let result = writer.write(frame(width: 960, height: 1080), cameraName: "Garagem", date: date)
        XCTAssertEqual(result, .failure(.writeFailed))
    }

    @MainActor
    func testNoFrameYetFails() async {
        let player = FakeCameraPlayer()
        let result = await writer.save(from: player, cameraName: "Garagem")
        XCTAssertEqual(result, .failure(.noFrame))
    }

    @MainActor
    func testSavesThePlayersFrame() async throws {
        let player = FakeCameraPlayer()
        player.frame = frame(width: 960, height: 1080)
        let url = try await writer.save(from: player, cameraName: "Sala/Cozinha").get()
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Sala-Cozinha "))
        XCTAssertEqual(try properties(of: url).width, 1920)
    }
}
