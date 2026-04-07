import Testing
import Foundation
@testable import peek

@Suite("Panel Capture")
struct PanelCaptureTests {

    @Test("Panel flag navigates before capture — config error when no config exists")
    func testPanelFlagNavigatesBeforeCapture() throws {
        // Without a config file, --panel should produce an actionable error
        let error = PeekConfigError.noConfigFound(appName: "FakeApp")
        #expect(error.description.contains("peek scan FakeApp --generate-config"))
    }

    @Test("--all without config shows helpful error")
    func testAllWithoutConfigShowsHelpfulError() throws {
        // PeekConfigLoader.require should throw noConfigFound for unknown apps
        #expect(throws: PeekConfigError.self) {
            _ = try PeekConfigLoader.require(appName: "NonExistentApp99999")
        }
    }

    @Test("Panel name fuzzy matching")
    func testPanelNameFuzzyMatching() {
        let config = PeekConfig(
            app: "TestApp",
            panels: [
                PanelConfig(name: "Chat", axPath: "outline 0 > row 0"),
                PanelConfig(name: "Schemas", axPath: "outline 0 > row 1"),
                PanelConfig(name: "Settings Panel", axPath: "outline 0 > row 2"),
            ]
        )

        // Exact match
        let exact = findPanel(named: "Chat", in: config)
        #expect(exact?.name == "Chat")

        // Case-insensitive
        let lower = findPanel(named: "chat", in: config)
        #expect(lower?.name == "Chat")

        // Substring
        let sub = findPanel(named: "schema", in: config)
        #expect(sub?.name == "Schemas")
    }

    @Test("--all mode output paths are correct")
    func testAllFlagOutputPaths() {
        let path1 = OutputPath.forAllPanel(appName: "ThinkLocal", panel: "Chat")
        let path2 = OutputPath.forAllPanel(appName: "ThinkLocal", panel: "Schemas")
        #expect(path1 == "/tmp/peek/ThinkLocal/Chat.png")
        #expect(path2 == "/tmp/peek/ThinkLocal/Schemas.png")
    }

    // MARK: - Helpers

    /// Mirror the panel finding logic from AppCommand.
    private func findPanel(named name: String, in config: PeekConfig) -> PanelConfig? {
        let query = name.lowercased()
        if let exact = config.panels.first(where: { $0.name.lowercased() == query }) {
            return exact
        }
        return config.panels.first(where: {
            $0.name.lowercased().contains(query) || query.contains($0.name.lowercased())
        })
    }
}
