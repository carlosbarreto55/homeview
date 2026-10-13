import os

extension Logger {
    private static let subsystem = "com.carloseduardo.HomeView"

    static let player = Logger(subsystem: subsystem, category: "player")
    static let panel = Logger(subsystem: subsystem, category: "panel")
}
