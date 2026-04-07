import ArgumentParser
import Foundation

struct App: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture a native macOS app window."
    )

    @Argument(help: "The application name (e.g., ThinkLocal).")
    var name: String

    @Option(help: "Capture a specific panel by name.")
    var panel: String?

    @Flag(help: "Capture all configured panels.")
    var all = false

    @Option(name: .shortAndLong, help: "Output file path.")
    var output: String?

    func run() async throws {
        // Panel and --all are handled by T09 (panel capture)
        if panel != nil || all {
            try await captureWithPanels()
            return
        }

        try await captureSingle()
    }

    // MARK: - Single window capture

    private func captureSingle() async throws {
        let windows = WindowDiscovery.discover(appName: name)

        guard !windows.isEmpty else {
            throw PeekError.appNotRunning(name)
        }

        // Check for ambiguous match (multiple apps)
        let groups = WindowDiscovery.groupByApp(windows)
        if groups.count > 1 {
            throw PeekError.ambiguousMatch(
                query: name,
                candidates: groups.keys.sorted()
            )
        }

        // Get the main (largest) window
        let userWindows = windows.filter { WindowDiscovery.isUserWindow($0) }
        guard let main = WindowDiscovery.mainWindow(from: userWindows.isEmpty ? windows : userWindows) else {
            throw PeekError.noWindows(name)
        }

        let outputPath = OutputPath.forCapture(
            appName: main.ownerName,
            customPath: output
        )

        let result = try await WindowCapture.capture(
            windowID: main.windowID,
            outputPath: outputPath
        )

        // AX-1: stdout prints only the path
        print(result)
    }

    // MARK: - Panel capture (--panel and --all)

    private func captureWithPanels() async throws {
        // Load config (required for panel operations)
        let config: PeekConfig
        do {
            config = try PeekConfigLoader.require(appName: name)
        } catch {
            throw error
        }

        // Find the app's windows
        let windows = WindowDiscovery.discover(appName: name)
        guard !windows.isEmpty else {
            throw PeekError.appNotRunning(name)
        }

        let groups = WindowDiscovery.groupByApp(windows)
        if groups.count > 1 {
            throw PeekError.ambiguousMatch(
                query: name,
                candidates: groups.keys.sorted()
            )
        }

        let actualAppName = windows[0].ownerName
        let pid = windows[0].ownerPID

        if all {
            // Capture all configured panels
            for panelConfig in config.panels {
                try await capturePanel(
                    panelConfig: panelConfig,
                    appName: actualAppName,
                    pid: pid,
                    windows: windows
                )
            }
        } else if let panelName = panel {
            // Find matching panel (fuzzy match AX-3)
            guard let panelConfig = findPanel(named: panelName, in: config) else {
                let available = config.panels.map(\.name).joined(separator: ", ")
                throw PeekError.panelNotFound(
                    panel: panelName,
                    appName: actualAppName,
                    available: available
                )
            }
            try await capturePanel(
                panelConfig: panelConfig,
                appName: actualAppName,
                pid: pid,
                windows: windows
            )
        }
    }

    private func capturePanel(
        panelConfig: PanelConfig,
        appName: String,
        pid: pid_t,
        windows: [DiscoveredWindow]
    ) async throws {
        // Navigate to the panel using AX
        try AXNavigator.navigate(pid: pid, axPath: panelConfig.axPath)

        // Wait for UI to settle
        try await Task.sleep(for: .milliseconds(500))

        // Determine output path
        let outputPath: String
        if all {
            outputPath = OutputPath.forAllPanel(appName: appName, panel: panelConfig.name)
        } else {
            outputPath = OutputPath.forCapture(
                appName: appName,
                panel: panelConfig.name,
                customPath: output
            )
        }

        // Capture
        let userWindows = windows.filter { WindowDiscovery.isUserWindow($0) }
        guard let main = WindowDiscovery.mainWindow(from: userWindows.isEmpty ? windows : userWindows) else {
            throw PeekError.noWindows(appName)
        }

        let result = try await WindowCapture.capture(
            windowID: main.windowID,
            outputPath: outputPath
        )
        print(result)
    }

    private func findPanel(named name: String, in config: PeekConfig) -> PanelConfig? {
        let query = name.lowercased()
        // Exact match first
        if let exact = config.panels.first(where: { $0.name.lowercased() == query }) {
            return exact
        }
        // Substring match
        return config.panels.first(where: {
            $0.name.lowercased().contains(query) || query.contains($0.name.lowercased())
        })
    }
}

// MARK: - Errors

enum PeekError: Error, CustomStringConvertible {
    case appNotRunning(String)
    case noWindows(String)
    case ambiguousMatch(query: String, candidates: [String])
    case panelNotFound(panel: String, appName: String, available: String)

    var description: String {
        switch self {
        case .appNotRunning(let name):
            return "Error: \"\(name)\" is not running. Start it with: open -a \"\(name)\""
        case .noWindows(let name):
            return "Error: \"\(name)\" has no capturable windows."
        case .ambiguousMatch(let query, let candidates):
            let list = candidates.joined(separator: "\n  ")
            return "Error: \"\(query)\" matches multiple apps:\n  \(list)\nBe more specific."
        case .panelNotFound(let panel, let appName, let available):
            return "Error: panel \"\(panel)\" not found for \"\(appName)\". Available: \(available)"
        }
    }
}
