import Testing
@testable import peek

@Suite("Version")
struct VersionTests {

    @Test("Version flag shows version")
    func testVersionFlagShowsVersion() {
        // The version is set in Peek.swift CommandConfiguration
        let config = Peek.configuration
        #expect(!config.version.isEmpty, "Version should not be empty")
        #expect(config.version.contains("."), "Version should contain a dot (semver)")
    }
}
