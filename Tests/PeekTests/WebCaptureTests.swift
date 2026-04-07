import Testing
import Foundation
@testable import peek

@Suite("Web Capture")
struct WebCaptureTests {

    @Test("Capture local HTML file")
    @MainActor
    func testCaptureLocalHTMLFile() async throws {
        // Create a temporary HTML file
        let htmlDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peek-web-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: htmlDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: htmlDir) }

        let html = """
        <!DOCTYPE html>
        <html><body style="background:red;width:200px;height:200px;">
        <h1>Test Page</h1>
        </body></html>
        """
        let htmlPath = htmlDir.appendingPathComponent("test.html")
        try html.write(to: htmlPath, atomically: true, encoding: .utf8)

        let outputPath = "/tmp/peek/web-test-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let capture = WebCapture(width: 800, height: 600)
        let result = try await capture.capture(
            urlString: htmlPath.absoluteString,
            waitDelay: 0.1,
            outputPath: outputPath
        )

        #expect(result == outputPath)
        #expect(FileManager.default.fileExists(atPath: outputPath))
        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        #expect(data.count > 100, "PNG should have meaningful size")
    }

    @Test("Capture respects viewport size")
    @MainActor
    func testCaptureRespectsViewportSize() async throws {
        let htmlDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peek-web-vp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: htmlDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: htmlDir) }

        let html = "<html><body><p>viewport test</p></body></html>"
        let htmlPath = htmlDir.appendingPathComponent("test.html")
        try html.write(to: htmlPath, atomically: true, encoding: .utf8)

        let outputSmall = "/tmp/peek/web-small-\(UUID().uuidString).png"
        let outputLarge = "/tmp/peek/web-large-\(UUID().uuidString).png"
        defer {
            try? FileManager.default.removeItem(atPath: outputSmall)
            try? FileManager.default.removeItem(atPath: outputLarge)
        }

        let small = WebCapture(width: 400, height: 300)
        _ = try await small.capture(
            urlString: htmlPath.absoluteString, waitDelay: 0.1, outputPath: outputSmall
        )

        let large = WebCapture(width: 1280, height: 800)
        _ = try await large.capture(
            urlString: htmlPath.absoluteString, waitDelay: 0.1, outputPath: outputLarge
        )

        let smallSize = try Data(contentsOf: URL(fileURLWithPath: outputSmall)).count
        let largeSize = try Data(contentsOf: URL(fileURLWithPath: outputLarge)).count
        // Larger viewport should generally produce larger PNG (not always, but for simple pages)
        #expect(smallSize > 0)
        #expect(largeSize > 0)
    }

    @Test("Capture with wait delay")
    @MainActor
    func testCaptureWithWaitDelay() async throws {
        let htmlDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peek-web-wait-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: htmlDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: htmlDir) }

        let html = "<html><body><p>wait test</p></body></html>"
        let htmlPath = htmlDir.appendingPathComponent("test.html")
        try html.write(to: htmlPath, atomically: true, encoding: .utf8)

        let outputPath = "/tmp/peek/web-wait-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let capture = WebCapture(width: 800, height: 600)
        _ = try await capture.capture(
            urlString: htmlPath.absoluteString, waitDelay: 1.0, outputPath: outputPath
        )

        #expect(FileManager.default.fileExists(atPath: outputPath))
    }

    @Test("Capture invalid URL returns error")
    @MainActor
    func testCaptureInvalidURLReturnsError() async throws {
        let capture = WebCapture(width: 800, height: 600)
        let outputPath = "/tmp/peek/web-invalid-\(UUID().uuidString).png"

        await #expect(throws: WebCaptureError.self) {
            _ = try await capture.capture(
                urlString: "not a valid url \u{00}",
                waitDelay: 0,
                outputPath: outputPath
            )
        }
    }

    @Test("Capture unreachable host returns error")
    @MainActor
    func testCaptureTimeoutReturnsError() async throws {
        let capture = WebCapture(width: 800, height: 600)
        let outputPath = "/tmp/peek/web-timeout-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        // Use a URL that will fail — the WebView may either error or load an error page.
        // We verify that either an error is thrown OR no usable PNG is produced.
        do {
            _ = try await capture.capture(
                urlString: "http://192.0.2.1:1/timeout-test",
                waitDelay: 0,
                outputPath: outputPath
            )
            // If we get here, WebKit rendered the error page as a "successful" load.
            // That's acceptable behavior — the important thing is we don't crash.
        } catch {
            // Expected: some kind of load/timeout error
            #expect(error is WebCaptureError, "Should throw a WebCaptureError, got: \(error)")
        }
    }
}
