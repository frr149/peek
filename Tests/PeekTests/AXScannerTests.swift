import Testing
@testable import peek

@Suite("AX Scanner")
struct AXScannerTests {

    /// Helper: find any visible app name.
    private func anyVisibleAppName() -> String? {
        let apps = WindowDiscovery.listApps()
        return apps.first?.name
    }

    @Test("Scan a visible app returns non-empty tree")
    func testScanFinderReturnsNonEmptyTree() throws {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows on this machine") {
                Issue.record()
            }
            return
        }
        let nodes = try AXScanner.scan(appName: appName)
        #expect(!nodes.isEmpty, "Scan should return at least one node for \(appName)")
    }

    @Test("Scan respects depth limit")
    func testScanRespectsDepthLimit() throws {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows on this machine") {
                Issue.record()
            }
            return
        }
        let shallow = try AXScanner.scan(appName: appName, maxDepth: 1)
        let deep = try AXScanner.scan(appName: appName, maxDepth: 4)

        // Count total nodes in each
        func countNodes(_ nodes: [AXNode]) -> Int {
            nodes.reduce(0) { $0 + 1 + countNodes($1.children) }
        }

        let shallowCount = countNodes(shallow)
        let deepCount = countNodes(deep)
        // Deeper scan should have at least as many nodes (usually more)
        #expect(deepCount >= shallowCount,
                "Deeper scan (\(deepCount)) should have >= nodes than shallow (\(shallowCount))")
    }

    @Test("Generate config outputs valid YAML")
    func testGenerateConfigOutputsValidYAML() throws {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows on this machine") {
                Issue.record()
            }
            return
        }
        let nodes = try AXScanner.scan(appName: appName, maxDepth: 3)
        let yaml = AXScanner.generateConfig(appName: appName, nodes: nodes)

        #expect(yaml.contains("app: \(appName)"))
        #expect(yaml.contains("panels:"))
    }
}
