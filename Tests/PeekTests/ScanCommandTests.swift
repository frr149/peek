import Testing
@testable import peek

@Suite("Scan Command")
struct ScanCommandTests {

    private func anyVisibleAppName() -> String? {
        WindowDiscovery.listApps().first?.name
    }

    @Test("Scan command outputs tree")
    func testScanCommandOutputsTree() throws {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows") { Issue.record() }
            return
        }
        let nodes = try AXScanner.scan(appName: appName, maxDepth: 2)
        let tree = AXScanner.formatTree(nodes)
        #expect(!tree.isEmpty, "Tree output should not be empty")
    }

    @Test("Scan command generate config outputs YAML")
    func testScanCommandGenerateConfigOutputsYAML() throws {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows") { Issue.record() }
            return
        }
        let nodes = try AXScanner.scan(appName: appName, maxDepth: 3)
        let yaml = AXScanner.generateConfig(appName: appName, nodes: nodes)
        #expect(yaml.contains("app:"))
        #expect(yaml.contains("panels:"))
    }

    @Test("Scan command respects depth")
    func testScanCommandRespectsDepth() throws {
        guard let appName = anyVisibleAppName() else {
            withKnownIssue("No visible app windows") { Issue.record() }
            return
        }
        let shallow = try AXScanner.scan(appName: appName, maxDepth: 1)
        let deep = try AXScanner.scan(appName: appName, maxDepth: 3)

        func countNodes(_ nodes: [AXNode]) -> Int {
            nodes.reduce(0) { $0 + 1 + countNodes($1.children) }
        }

        #expect(countNodes(deep) >= countNodes(shallow))
    }
}
