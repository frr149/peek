import ArgumentParser

struct App: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture a native macOS app window."
    )

    @Argument(help: "The application name (e.g., ThinkLocal).")
    var name: String

    @Option(help: "Capture a specific panel by name.")
    var panel: String?

    @Flag(help: "Capture all configured panels.")
    var all = false

    @Option(name: .shortAndLong, help: "Output file path.")
    var output: String?

    func run() throws {
        print("TODO: capture app '\(name)'")
    }
}
