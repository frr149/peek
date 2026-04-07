import Testing
import Foundation
import AppKit
@testable import peek

/// Check if ThinkLocal is running (must be a free function for @Suite trait).
private func checkThinkLocalRunning() -> Bool {
    let windows = WindowDiscovery.discover(appName: "Think Local")
    return !windows.isEmpty
}

/// Integration test for ThinkLocal (or "Think Local") panel capture.
/// Requires the app to be running — skipped gracefully if not.
@Suite("ThinkLocal Integration", .enabled(if: checkThinkLocalRunning()))
struct ThinkLocalIntegrationTests {

    @Test("Capture all ThinkLocal panels")
    @MainActor
    func testCaptureAllThinkLocalPanels() async throws {
        let windows = WindowDiscovery.discover(appName: "Think Local")
        guard !windows.isEmpty else {
            Issue.record("ThinkLocal not running")
            return
        }

        let userWindows = windows.filter { WindowDiscovery.isUserWindow($0) }
        guard let main = WindowDiscovery.mainWindow(from: userWindows) else {
            Issue.record("No main window for ThinkLocal")
            return
        }

        // Capture main window
        let outputPath = "/tmp/peek/thinklocal-integration-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let result = try await WindowCapture.capture(
            windowID: main.windowID,
            outputPath: outputPath
        )

        #expect(FileManager.default.fileExists(atPath: result))
        let data = try Data(contentsOf: URL(fileURLWithPath: result))
        #expect(data.count > 0, "PNG should have non-zero file size")
    }

    @Test("Capture completes under 10 seconds")
    @MainActor
    func testCaptureCompletesUnderTenSeconds() async throws {
        let windows = WindowDiscovery.discover(appName: "Think Local")
        guard !windows.isEmpty else { return }
        let userWindows = windows.filter { WindowDiscovery.isUserWindow($0) }
        guard let main = WindowDiscovery.mainWindow(from: userWindows) else { return }

        let start = Date()
        let outputPath = "/tmp/peek/thinklocal-speed-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        _ = try await WindowCapture.capture(
            windowID: main.windowID,
            outputPath: outputPath
        )

        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 10.0, "Capture should complete in under 10 seconds, took \(elapsed)s")
    }

    @Test("Focus not stolen during capture")
    @MainActor
    func testFocusNotStolenDuringCapture() async throws {
        let windows = WindowDiscovery.discover(appName: "Think Local")
        guard !windows.isEmpty else { return }
        let userWindows = windows.filter { WindowDiscovery.isUserWindow($0) }
        guard let main = WindowDiscovery.mainWindow(from: userWindows) else { return }

        let frontBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        let outputPath = "/tmp/peek/thinklocal-focus-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        _ = try await WindowCapture.capture(
            windowID: main.windowID,
            outputPath: outputPath
        )

        let frontAfter = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        #expect(frontBefore == frontAfter, "Frontmost app should not change during capture")
    }
}
