import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Errors from window capture.
enum WindowCaptureError: Error, CustomStringConvertible {
    case windowNotFound(CGWindowID)
    case capturePermissionDenied
    case captureFailed(String)
    case saveFailed(String)

    var description: String {
        switch self {
        case .windowNotFound(let id):
            return "Error: window ID \(id) not found. The window may have been closed."
        case .capturePermissionDenied:
            return "Error: Screen Recording permission denied. Grant it in System Settings > Privacy & Security > Screen Recording."
        case .captureFailed(let detail):
            return "Error: capture failed: \(detail)"
        case .saveFailed(let detail):
            return "Error: failed to save PNG: \(detail)"
        }
    }
}

/// Captures a window's pixels to a PNG file using ScreenCaptureKit.
enum WindowCapture {

    /// Capture a specific window by its CGWindowID and save to a PNG file.
    ///
    /// Uses ScreenCaptureKit for modern, non-focus-stealing capture.
    /// The target app is never activated or brought to front.
    ///
    /// - Parameters:
    ///   - windowID: The CGWindowID to capture.
    ///   - outputPath: Where to save the PNG file.
    /// - Returns: The absolute path to the saved PNG.
    @MainActor
    static func capture(windowID: CGWindowID, outputPath: String) async throws -> String {
        // Get available content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
        } catch {
            throw WindowCaptureError.capturePermissionDenied
        }

        // Find the target window in SCShareableContent
        guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
            throw WindowCaptureError.windowNotFound(windowID)
        }

        // Create a filter for just this window
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)

        // Configure capture at full resolution (Retina)
        let config = SCStreamConfiguration()
        config.width = Int(scWindow.frame.width) * 2  // @2x for Retina
        config.height = Int(scWindow.frame.height) * 2
        config.showsCursor = false
        config.captureResolution = .best

        // Capture the image
        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            throw WindowCaptureError.captureFailed(error.localizedDescription)
        }

        // Save as PNG
        try savePNG(image: image, to: outputPath)

        return outputPath
    }

    // MARK: - Private

    private static func savePNG(image: CGImage, to path: String) throws {
        // Ensure parent directory exists
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil
        ) else {
            throw WindowCaptureError.saveFailed("cannot create image destination at \(path)")
        }

        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw WindowCaptureError.saveFailed("failed to write PNG to \(path)")
        }
    }
}
