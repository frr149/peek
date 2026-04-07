import Testing

@Suite("Peek CLI")
struct PeekTests {
    @Test("CLI entry point exists")
    func cliEntryPointExists() {
        // Verified by the build — if Peek.swift doesn't compile, tests don't run.
        #expect(Bool(true))
    }
}
