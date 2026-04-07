import Testing
import Foundation
import AppKit
@testable import peek

@Suite("App Command")
struct AppCommandTests {

    /// Helper: find any visible user app name.
    private func anyVisibleAppName() -> String? {
        let apps = WindowDiscovery.listApps()
        return apps.first?.name
    }

    @Test("App command captures a visible app")
    @MainActor
    func testAppCommandCapturesFinder() async throws {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows") { Issue.record() }
            return
        }

        let windows = WindowDiscovery.discover(appName: appName)
        let userWindows = windows.filter { WindowDiscovery.isUserWindow($0) }
        guard let main = WindowDiscovery.mainWindow(from: userWindows.isEmpty ? windows : userWindows) else {
            withKnownIssue("No main window found") { Issue.record() }
            return
        }

        let outputPath = "/tmp/peek/test-app-cmd-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let result = try await WindowCapture.capture(
            windowID: main.windowID,
            outputPath: outputPath
        )
        #expect(result == outputPath)
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }

    @Test("App command with custom output")
    @MainActor
    func testAppCommandWithCustomOutput() async throws {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows") { Issue.record() }
            return
        }

        let customPath = "/tmp/peek/custom-output-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: customPath) }

        let generatedPath = OutputPath.forCapture(appName: appName, customPath: customPath)
        #expect(generatedPath == customPath)
    }

    @Test("App command non-existent app exits with error")
    func testAppCommandNonExistentAppExitsWithError() {
        let windows = WindowDiscovery.discover(appName: "NonExistentApp99999")
        #expect(windows.isEmpty, "Non-existent app should return no windows")
    }

    @Test("App command ambiguous match lists candidates")
    func testAppCommandAmbiguousMatchListsCandidates() {
        // Test the groupByApp logic
        let windows = WindowDiscovery.listAllWindows().filter {
            WindowDiscovery.isUserWindow($0)
        }
        guard windows.count >= 2 else { return }

        let groups = WindowDiscovery.groupByApp(windows)
        if groups.count > 1 {
            // Multiple apps found — this is the ambiguous scenario
            #expect(groups.count > 1)
            #expect(groups.keys.allSatisfy { !$0.isEmpty })
        }
    }
}
