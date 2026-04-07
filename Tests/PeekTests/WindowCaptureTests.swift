import Testing
import Foundation
import AppKit
@testable import peek

@Suite("Window Capture")
struct WindowCaptureTests {

    /// Helper: find any visible user window.
    private func anyVisibleWindow() -> DiscoveredWindow? {
        let windows = WindowDiscovery.listAllWindows()
        return windows.first(where: { WindowDiscovery.isUserWindow($0) })
    }

    @Test("Capture a visible window produces PNG")
    func testCaptureFinderWindowProducesPNG() async throws {
        guard let window = anyVisibleWindow() else {
            withKnownIssue("No visible windows on this machine") {
                Issue.record()
            }
            return
        }

        let outputPath = "/tmp/peek/test-capture-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let result = try await WindowCapture.capture(
            windowID: window.windowID,
            outputPath: outputPath
        )
        #expect(result == outputPath)
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }

    @Test("Captured image has non-zero dimensions")
    func testCapturedImageHasNonZeroDimensions() async throws {
        guard let window = anyVisibleWindow() else {
            withKnownIssue("No visible windows on this machine") {
                Issue.record()
            }
            return
        }

        let outputPath = "/tmp/peek/test-dims-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        _ = try await WindowCapture.capture(
            windowID: window.windowID,
            outputPath: outputPath
        )

        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        #expect(data.count > 100, "PNG should have meaningful size")
    }

    @Test("Capture does not change active application")
    func testCaptureDoesNotChangeActiveApplication() async throws {
        guard let window = anyVisibleWindow() else {
            withKnownIssue("No visible windows on this machine") {
                Issue.record()
            }
            return
        }

        let outputPath = "/tmp/peek/test-focus-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        // Record current frontmost app
        let frontBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        _ = try await WindowCapture.capture(
            windowID: window.windowID,
            outputPath: outputPath
        )

        let frontAfter = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        #expect(frontBefore == frontAfter, "Capture should not change frontmost app")
    }

    @Test("Output path matches requested")
    func testOutputPathMatchesRequested() async throws {
        guard let window = anyVisibleWindow() else {
            withKnownIssue("No visible windows on this machine") {
                Issue.record()
            }
            return
        }

        let outputPath = "/tmp/peek/test-path-match-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let result = try await WindowCapture.capture(
            windowID: window.windowID,
            outputPath: outputPath
        )
        #expect(result == outputPath)
    }
}
