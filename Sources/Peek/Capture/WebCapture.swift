import AppKit
import Foundation
import WebKit

/// Errors from web capture.
enum WebCaptureError: Error, CustomStringConvertible {
    case invalidURL(String)
    case loadFailed(String)
    case timeout(String)
    case captureFailed(String)
    case saveFailed(String)

    var description: String {
        switch self {
        case .invalidURL(let url):
            return "Error: invalid URL \"\(url)\". Provide a full URL like http://localhost:3000"
        case .loadFailed(let detail):
            return "Error: page load failed: \(detail)"
        case .timeout(let url):
            return "Error: timeout loading \"\(url)\" (30s). Check the server is running."
        case .captureFailed(let detail):
            return "Error: web capture failed: \(detail)"
        case .saveFailed(let detail):
            return "Error: failed to save PNG: \(detail)"
        }
    }
}

/// Captures a web page headlessly using WKWebView.
@MainActor
final class WebCapture: NSObject, WKNavigationDelegate {

    private let webView: WKWebView
    private var continuation: CheckedContinuation<Void, any Error>?
    private let timeoutSeconds: TimeInterval = 30

    /// Create a web capture instance with the given viewport size.
    init(width: Int, height: Int) {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: width, height: height),
            configuration: config
        )
        // Make the web view render off-screen without showing a window
        webView.setValue(false, forKey: "drawsBackground")
        self.webView = webView

        super.init()
        self.webView.navigationDelegate = self
    }

    /// Load a URL, wait for it to finish, then capture to PNG.
    ///
    /// - Parameters:
    ///   - urlString: The URL to capture.
    ///   - waitDelay: Extra seconds to wait after page load (for SPAs).
    ///   - outputPath: Where to save the PNG.
    /// - Returns: The absolute path to the saved PNG.
    func capture(urlString: String, waitDelay: Double, outputPath: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw WebCaptureError.invalidURL(urlString)
        }

        // Load the page
        let request = URLRequest(url: url, timeoutInterval: timeoutSeconds)
        webView.load(request)

        // Wait for navigation to complete
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            self.continuation = cont
        }

        // Extra wait for JavaScript rendering
        if waitDelay > 0 {
            try await Task.sleep(for: .seconds(waitDelay))
        }

        // Take snapshot
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = NSNumber(value: webView.frame.width)

        let image: NSImage
        do {
            image = try await webView.takeSnapshot(configuration: config)
        } catch {
            throw WebCaptureError.captureFailed(error.localizedDescription)
        }

        // Save as PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw WebCaptureError.captureFailed("failed to convert snapshot to PNG")
        }

        // Ensure parent directory exists
        let dir = (outputPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        do {
            try pngData.write(to: URL(fileURLWithPath: outputPath))
        } catch {
            throw WebCaptureError.saveFailed(error.localizedDescription)
        }

        return outputPath
    }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        MainActor.assumeIsolated {
            continuation?.resume()
            continuation = nil
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        MainActor.assumeIsolated {
            continuation?.resume(throwing: WebCaptureError.loadFailed(error.localizedDescription))
            continuation = nil
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        MainActor.assumeIsolated {
            let nsError = error as NSError
            if nsError.code == NSURLErrorTimedOut {
                continuation?.resume(throwing: WebCaptureError.timeout(webView.url?.absoluteString ?? "unknown"))
            } else {
                continuation?.resume(throwing: WebCaptureError.loadFailed(error.localizedDescription))
            }
            continuation = nil
        }
    }
}
