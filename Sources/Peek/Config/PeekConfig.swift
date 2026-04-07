import Foundation
import Yams

/// Configuration for a single panel in an app.
struct PanelConfig: Codable, Sendable {
    let name: String
    let axPath: String

    enum CodingKeys: String, CodingKey {
        case name
        case axPath = "ax_path"
    }
}

/// Per-app configuration loaded from YAML.
struct PeekConfig: Codable, Sendable {
    let app: String
    let panels: [PanelConfig]
}

/// Errors from config parsing.
enum PeekConfigError: Error, CustomStringConvertible {
    case malformedYAML(path: String, detail: String)
    case noConfigFound(appName: String)

    var description: String {
        switch self {
        case .malformedYAML(let path, let detail):
            return "Error: malformed YAML in \(path): \(detail)"
        case .noConfigFound(let appName):
            return "Error: No config for \"\(appName)\". Generate one with: peek scan \(appName) --generate-config > ~/.config/peek/\(appName).yml"
        }
    }
}

/// Loads per-app configuration from YAML files.
enum PeekConfigLoader {

    /// Search paths for config files.
    private static var searchDirs: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.config/peek",
            ".",  // current directory fallback
        ]
    }

    /// Load configuration for a given app name.
    ///
    /// Lookup strategy (AX-3 fuzzy matching):
    /// 1. Exact filename: `<AppName>.yml`
    /// 2. Case-insensitive match on filenames in config dir
    /// 3. Normalized match (strip spaces/hyphens)
    ///
    /// Also checks for `.peek.yml` in the current directory.
    ///
    /// - Returns: The parsed config, or nil if no config file found.
    /// - Throws: `PeekConfigError.malformedYAML` if file exists but is invalid.
    static func load(appName: String) throws -> PeekConfig? {
        // Check .peek.yml in current directory first
        let localConfig = ".peek.yml"
        if FileManager.default.fileExists(atPath: localConfig) {
            let config = try parseFile(localConfig)
            if normalize(config.app) == normalize(appName) {
                return config
            }
        }

        // Search config directories
        for dir in searchDirs {
            if let path = findConfigFile(appName: appName, inDirectory: dir) {
                return try parseFile(path)
            }
        }

        return nil
    }

    /// Require config or throw an actionable error (AX-5).
    static func require(appName: String) throws -> PeekConfig {
        guard let config = try load(appName: appName) else {
            throw PeekConfigError.noConfigFound(appName: appName)
        }
        return config
    }

    // MARK: - Private

    private static func parseFile(_ path: String) throws -> PeekConfig {
        let content: String
        do {
            content = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw PeekConfigError.malformedYAML(path: path, detail: "cannot read file: \(error.localizedDescription)")
        }

        do {
            let decoder = YAMLDecoder()
            return try decoder.decode(PeekConfig.self, from: content)
        } catch {
            throw PeekConfigError.malformedYAML(path: path, detail: "\(error)")
        }
    }

    private static func findConfigFile(appName: String, inDirectory dir: String) -> String? {
        let fm = FileManager.default
        let normalizedQuery = normalize(appName)

        // Try exact filename first
        let exactPath = "\(dir)/\(appName).yml"
        if fm.fileExists(atPath: exactPath) {
            return exactPath
        }

        // List directory and fuzzy match
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else {
            return nil
        }

        for entry in entries where entry.hasSuffix(".yml") || entry.hasSuffix(".yaml") {
            let baseName = String(entry.dropLast(entry.hasSuffix(".yaml") ? 5 : 4))
            if normalize(baseName) == normalizedQuery {
                return "\(dir)/\(entry)"
            }
        }

        return nil
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}
