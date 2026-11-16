import Foundation

enum LoginLauncher {
    static let label = "io.github.leooochen.kindledock.login"
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func configure(enabled: Bool) throws {
        // Development builds must never leave a login item pointing at dist/.
        let app = Bundle.main.bundleURL.standardizedFileURL.path
        guard app == "/Applications/KindleDock.app" else { return }
        if enabled {
            let contents: [String: Any] = [
                "Label": label,
                "ProgramArguments": ["/usr/bin/open", "-g", "-a", app],
                "RunAtLoad": true,
                "LimitLoadToSessionType": "Aqua",
                "ProcessType": "Background"
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: contents, format: .xml, options: 0)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // launchd reads it on the next login; the app is already running now.
            try data.write(to: url, options: .atomic)
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
