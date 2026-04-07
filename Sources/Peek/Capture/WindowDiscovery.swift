import CoreGraphics
import Foundation

/// Information about a discovered window.
struct DiscoveredWindow {
    let windowID: CGWindowID
    let ownerName: String
    let title: String
    let bounds: CGRect
    let layer: Int
    let ownerPID: pid_t
}

/// Discovers windows of running applications using CoreGraphics.
enum WindowDiscovery {

    /// Find all windows belonging to an app matching the given name.
    ///
    /// Matching strategy (AX-3):
    /// 1. Exact match (case-insensitive)
    /// 2. Normalized match (strip spaces/hyphens, case-insensitive)
    /// 3. Substring match as fallback
    static func discover(appName: String) -> [DiscoveredWindow] {
        let allWindows = listAllWindows()
        let query = normalize(appName)

        // Phase 1: exact case-insensitive match on owner name
        let exact = allWindows.filter {
            $0.ownerName.lowercased() == appName.lowercased()
        }
        if !exact.isEmpty { return exact }

        // Phase 2: normalized match (strip spaces, hyphens)
        let normalized = allWindows.filter {
            normalize($0.ownerName) == query
        }
        if !normalized.isEmpty { return normalized }

        // Phase 3: substring match
        let substring = allWindows.filter {
            normalize($0.ownerName).contains(query) || query.contains(normalize($0.ownerName))
        }
        return substring
    }

    /// List all on-screen windows with their metadata.
    static func listAllWindows() -> [DiscoveredWindow] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var results: [DiscoveredWindow] = []
        for info in windowList {
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any]
            else {
                continue
            }

            // Skip windows with zero size (invisible system windows)
            let bounds = CGRect(
                x: boundsDict["X"] as? CGFloat ?? 0,
                y: boundsDict["Y"] as? CGFloat ?? 0,
                width: boundsDict["Width"] as? CGFloat ?? 0,
                height: boundsDict["Height"] as? CGFloat ?? 0
            )
            guard bounds.width > 0 && bounds.height > 0 else { continue }

            let title = info[kCGWindowName as String] as? String ?? ""

            results.append(DiscoveredWindow(
                windowID: windowID,
                ownerName: ownerName,
                title: title,
                bounds: bounds,
                layer: layer,
                ownerPID: ownerPID
            ))
        }
        return results
    }

    /// Find all unique app names that have visible windows.
    /// Returns tuples of (appName, windowCount, mainWindowSize).
    static func listApps() -> [(name: String, windowCount: Int, mainSize: CGSize)] {
        let windows = listAllWindows().filter { isUserWindow($0) }

        var appWindows: [String: [DiscoveredWindow]] = [:]
        for w in windows {
            appWindows[w.ownerName, default: []].append(w)
        }

        return appWindows
            .map { name, wins in
                let mainWindow = wins.max(by: {
                    $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height
                })
                let size = mainWindow?.bounds.size ?? .zero
                return (name: name, windowCount: wins.count, mainSize: size)
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Select the "main" window (largest by area) from a list of discovered windows.
    static func mainWindow(from windows: [DiscoveredWindow]) -> DiscoveredWindow? {
        windows.max(by: {
            $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height
        })
    }

    /// Group discovered windows by owner name — used when fuzzy match returns
    /// windows from multiple apps (ambiguous match).
    static func groupByApp(_ windows: [DiscoveredWindow]) -> [String: [DiscoveredWindow]] {
        Dictionary(grouping: windows, by: \.ownerName)
    }

    // MARK: - Private

    /// Normalize a string for fuzzy matching: lowercase, strip spaces and hyphens.
    private static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    /// Filter out system-level windows (menubar, dock, etc.).
    /// User windows are on layer 0.
    static func isUserWindow(_ window: DiscoveredWindow) -> Bool {
        window.layer == 0
    }
}
