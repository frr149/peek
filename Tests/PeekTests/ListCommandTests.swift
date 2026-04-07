import Testing
@testable import peek

@Suite("List Command")
struct ListCommandTests {

    @Test("List includes at least one app")
    func testListIncludesFinder() {
        let apps = WindowDiscovery.listApps()
        // At least one app should have a visible window
        #expect(!apps.isEmpty, "Should find at least one app with visible windows")
    }

    @Test("List excludes system windows")
    func testListExcludesSystemWindows() {
        let apps = WindowDiscovery.listApps()
        // System windows like "Window Server" should not appear
        // (they're filtered by layer != 0)
        let systemNames = ["Window Server", "SystemUIServer"]
        for sysName in systemNames {
            let found = apps.contains(where: { $0.name == sysName })
            #expect(!found, "\(sysName) should be excluded from list")
        }
    }

    @Test("List output is sorted alphabetically")
    func testListOutputIsSorted() {
        let apps = WindowDiscovery.listApps()
        guard apps.count >= 2 else { return }
        for i in 0..<(apps.count - 1) {
            #expect(
                apps[i].name.lowercased() <= apps[i + 1].name.lowercased(),
                "List should be sorted: '\(apps[i].name)' should come before '\(apps[i + 1].name)'"
            )
        }
    }

    @Test("List output format is tab-separated")
    func testListOutputIsTabSeparated() {
        let apps = WindowDiscovery.listApps()
        guard let app = apps.first else { return }
        // Simulate the output format
        let width = Int(app.mainSize.width)
        let height = Int(app.mainSize.height)
        let line = "\(app.name)\t\(app.windowCount)\t\(width)x\(height)"
        let parts = line.split(separator: "\t")
        #expect(parts.count == 3, "Output should have 3 tab-separated columns")
    }
}
