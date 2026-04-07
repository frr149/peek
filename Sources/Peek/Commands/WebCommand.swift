import ArgumentParser

struct Web: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture a web page headlessly using WebKit."
    )

    @Argument(help: "The URL to capture.")
    var url: String

    @Option(help: "Viewport width in pixels.")
    var width: Int = 1280

    @Option(help: "Viewport height in pixels.")
    var height: Int = 800

    @Option(help: "Seconds to wait after page load before capturing.")
    var wait: Double = 0.5

    @Option(name: .shortAndLong, help: "Output file path.")
    var output: String?

    func run() throws {
        print("TODO: capture web '\(url)'")
    }
}
