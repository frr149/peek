import Testing
@testable import peek

@Suite("Window Discovery")
struct WindowDiscoveryTests {

    /// Helper: find any app that currently has a visible user window (layer 0).
    private func anyVisibleAppName() -> String? {
        let windows = WindowDiscovery.listAllWindows()
        return windows.first(where: { WindowDiscovery.isUserWindow($0) })?.ownerName
    }

    @Test("Discover a visible app's window")
    func testDiscoverFinderWindow() {
        guard let appName = anyVisibleAppName() else {
            // No visible windows at all — skip gracefully
            withKnownIssue("No visible app windows on this machine") {
                Issue.record()
            }
            return
        }
        let windows = WindowDiscovery.discover(appName: appName)
        #expect(!windows.isEmpty, "\(appName) should have at least one window")
        #expect(windows.allSatisfy { $0.ownerName == appName })
    }

    @Test("Non-existent app returns empty array")
    func testDiscoverNonExistentAppReturnsEmpty() {
        let windows = WindowDiscovery.discover(appName: "NonExistentApp12345")
        #expect(windows.isEmpty)
    }

    @Test("Discovered window has position and size")
    func testDiscoveredWindowHasPositionAndSize() {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows on this machine") {
                Issue.record()
            }
            return
        }
        let windows = WindowDiscovery.discover(appName: appName)
        guard let window = windows.first else {
            Issue.record("No window found for \(appName)")
            return
        }
        #expect(window.bounds.width > 0)
        #expect(window.bounds.height > 0)
    }

    @Test("Fuzzy match ignores case")
    func testFuzzyMatchIgnoresCase() {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows on this machine") {
                Issue.record()
            }
            return
        }
        // Query with all-lowercase
        let windows = WindowDiscovery.discover(appName: appName.lowercased())
        #expect(!windows.isEmpty, "Should match '\(appName)' with '\(appName.lowercased())'")
    }

    @Test("Fuzzy match ignores spaces")
    func testFuzzyMatchIgnoresSpaces() {
        guard let appName = anyVisibleAppName(), appName.count >= 4 else {
            withKnownIssue("No visible app windows with long enough name") {
                Issue.record()
            }
            return
        }
        // Insert a space in the middle of the name
        let midIndex = appName.index(appName.startIndex, offsetBy: appName.count / 2)
        let spaced = String(appName[..<midIndex]) + " " + String(appName[midIndex...])
        let windows = WindowDiscovery.discover(appName: spaced)
        #expect(!windows.isEmpty, "Should match '\(appName)' with '\(spaced)'")
    }

    @Test("Substring match as fallback")
    func testSubstringMatchAsFallback() {
        guard let appName = anyVisibleAppName(), appName.count >= 4 else {
            withKnownIssue("No visible app windows with long enough name") {
                Issue.record()
            }
            return
        }
        // Use first 3+ characters as substring query
        let prefix = String(appName.prefix(max(3, appName.count - 1)))
        let windows = WindowDiscovery.discover(appName: prefix)
        #expect(!windows.isEmpty, "Should match '\(appName)' via substring '\(prefix)'")
    }
}
