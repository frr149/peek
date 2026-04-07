import Foundation

/// Generates consistent output paths for captured screenshots.
enum OutputPath {

    private static let baseDir = "/tmp/peek"

    /// Generate an output path for a single capture.
    ///
    /// - Parameters:
    ///   - appName: The application name.
    ///   - panel: Optional panel name.
    ///   - customPath: If provided, returned as-is.
    /// - Returns: The absolute path where the PNG should be saved.
    static func forCapture(
        appName: String,
        panel: String? = nil,
        customPath: String? = nil
    ) -> String {
        if let customPath {
            return customPath
        }

        ensureDirectory(baseDir)
        let timestamp = Self.timestamp()

        if let panel {
            return "\(baseDir)/\(appName)-\(panel)-\(timestamp).png"
        }
        return "\(baseDir)/\(appName)-\(timestamp).png"
    }

    /// Generate an output path for --all mode (panel capture, no timestamp).
    ///
    /// - Parameters:
    ///   - appName: The application name.
    ///   - panel: The panel name.
    /// - Returns: Path in the format `/tmp/peek/<AppName>/<Panel>.png`.
    static func forAllPanel(appName: String, panel: String) -> String {
        let dir = "\(baseDir)/\(appName)"
        ensureDirectory(dir)
        return "\(dir)/\(panel).png"
    }

    /// Generate an output path for web capture.
    ///
    /// - Parameters:
    ///   - url: The URL being captured.
    ///   - customPath: If provided, returned as-is.
    /// - Returns: The absolute path where the PNG should be saved.
    static func forWeb(url: String, customPath: String? = nil) -> String {
        if let customPath {
            return customPath
        }

        ensureDirectory(baseDir)
        let sanitized = sanitizeURLForFilename(url)
        let timestamp = Self.timestamp()
        return "\(baseDir)/\(sanitized)-\(timestamp).png"
    }

    /// Current timestamp in YYYYMMDD-HHmmss format.
    static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    // MARK: - Private

    private static func ensureDirectory(_ path: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    private static func sanitizeURLForFilename(_ url: String) -> String {
        var name = url
        // Remove protocol
        for prefix in ["https://", "http://", "file://"] {
            if name.hasPrefix(prefix) {
                name = String(name.dropFirst(prefix.count))
                break
            }
        }
        // Replace non-alphanumeric characters
        name = name.replacingOccurrences(of: "/", with: "_")
        name = name.replacingOccurrences(of: ":", with: "_")
        name = name.replacingOccurrences(of: "?", with: "_")
        name = name.replacingOccurrences(of: "&", with: "_")
        // Truncate to reasonable length
        if name.count > 60 {
            name = String(name.prefix(60))
        }
        return name
    }
}
