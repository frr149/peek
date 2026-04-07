import Testing
@testable import peek

@Suite("Output Path")
struct OutputPathTests {

    @Test("Default path contains app name")
    func testDefaultPathContainsAppName() {
        let path = OutputPath.forCapture(appName: "Finder")
        #expect(path.contains("Finder"))
        #expect(path.hasPrefix("/tmp/peek/"))
        #expect(path.hasSuffix(".png"))
    }

    @Test("Panel path contains panel name")
    func testPanelPathContainsPanelName() {
        let path = OutputPath.forCapture(appName: "ThinkLocal", panel: "Chat")
        #expect(path.contains("ThinkLocal"))
        #expect(path.contains("Chat"))
        #expect(path.hasSuffix(".png"))
    }

    @Test("Custom output path used as-is")
    func testCustomOutputPathUsedAsIs() {
        let custom = "/tmp/my-screenshot.png"
        let path = OutputPath.forCapture(appName: "Finder", customPath: custom)
        #expect(path == custom)
    }

    @Test("Timestamp format is YYYYMMDD-HHmmss")
    func testTimestampFormatIsCorrect() {
        let ts = OutputPath.timestamp()
        // Format: 20260407-183012
        #expect(ts.count == 15, "Timestamp should be 15 characters: YYYYMMDD-HHmmss")
        #expect(ts[ts.index(ts.startIndex, offsetBy: 8)] == "-")
        // All other characters should be digits
        let digits = ts.replacingOccurrences(of: "-", with: "")
        #expect(digits.allSatisfy { $0.isNumber })
    }

    @Test("--all mode puts panels in subdirectory")
    func testAllModePutsPanelsInSubdirectory() {
        let path = OutputPath.forAllPanel(appName: "ThinkLocal", panel: "Schemas")
        #expect(path == "/tmp/peek/ThinkLocal/Schemas.png")
    }
}
