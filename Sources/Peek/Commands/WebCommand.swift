import ArgumentParser
import Foundation

struct Web: AsyncParsableCommand {
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

    @MainActor
    func run() async throws {
        let outputPath = OutputPath.forWeb(url: url, customPath: output)
        let capture = WebCapture(width: width, height: height)

        let result = try await capture.capture(
            urlString: url,
            waitDelay: wait,
            outputPath: outputPath
        )

        // AX-1: stdout prints only the path
        print(result)
    }
}
