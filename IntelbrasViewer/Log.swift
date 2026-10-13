import os

extension Logger {
    private static let subsystem = "com.carloseduardo.IntelbrasViewer"

    static let player = Logger(subsystem: subsystem, category: "player")
    static let panel = Logger(subsystem: subsystem, category: "panel")
}
