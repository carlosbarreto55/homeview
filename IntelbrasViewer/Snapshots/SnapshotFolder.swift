import AppKit

/// `~/Pictures/Intelbras Viewer`, where snapshots are saved.
enum SnapshotFolder {
    static var url: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appending(path: "Intelbras Viewer", directoryHint: .isDirectory)
    }

    /// Creates the folder when it does not exist yet.
    static func create(at url: URL = SnapshotFolder.url) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Shows the folder in Finder, creating it first.
    static func open() {
        try? create()
        NSWorkspace.shared.open(url)
    }
}
