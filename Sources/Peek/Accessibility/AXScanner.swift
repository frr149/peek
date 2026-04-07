import ApplicationServices
import Foundation

/// A node in the accessibility tree.
struct AXNode: Sendable {
    let role: String
    let title: String
    let path: String
    let children: [AXNode]
    let isInteresting: Bool

    /// Roles considered "interesting" — elements that look like navigable panels/tabs.
    static let interestingRoles: Set<String> = [
        "AXButton", "AXRadioButton", "AXTab", "AXTabGroup",
        "AXRow", "AXOutlineRow", "AXMenuItem", "AXToolbar",
        "AXToolbarButton", "AXStaticText", "AXCell",
    ]

    /// Check if this element has a meaningful title (not empty, not just whitespace).
    var hasTitle: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Errors from AX scanning.
enum AXScanError: Error, CustomStringConvertible {
    case appNotRunning(String)
    case accessibilityDenied
    case noWindows(String)

    var description: String {
        switch self {
        case .appNotRunning(let name):
            return "Error: \"\(name)\" is not running. Start it with: open -a \"\(name)\""
        case .accessibilityDenied:
            return "Error: Accessibility permission denied. Grant it in System Settings > Privacy & Security > Accessibility."
        case .noWindows(let name):
            return "Error: \"\(name)\" has no windows. Make sure it has at least one window open."
        }
    }
}

/// Traverses an app's accessibility tree to discover navigable elements.
enum AXScanner {

    /// Scan an app's accessibility tree.
    ///
    /// - Parameters:
    ///   - appName: The app to scan (fuzzy matched via WindowDiscovery).
    ///   - maxDepth: Maximum traversal depth (default: 4).
    /// - Returns: Array of root AXNodes (one per window).
    static func scan(appName: String, maxDepth: Int = 4) throws -> [AXNode] {
        // Find the app via WindowDiscovery
        let windows = WindowDiscovery.discover(appName: appName)
        guard !windows.isEmpty else {
            // Check if the app is running at all (might have no visible windows)
            let allWindows = WindowDiscovery.listAllWindows()
            let matchingApps = allWindows.filter {
                $0.ownerName.lowercased().contains(appName.lowercased())
            }
            if matchingApps.isEmpty {
                throw AXScanError.appNotRunning(appName)
            }
            throw AXScanError.noWindows(appName)
        }

        // Get unique PIDs
        let pids = Set(windows.map(\.ownerPID))

        var roots: [AXNode] = []
        for pid in pids {
            let appElement = AXUIElementCreateApplication(pid)

            // Check accessibility access
            guard AXIsProcessTrusted() else {
                throw AXScanError.accessibilityDenied
            }

            // Get windows
            var windowsValue: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                appElement, kAXWindowsAttribute as CFString, &windowsValue
            )
            guard result == .success,
                  let axWindows = windowsValue as? [AXUIElement]
            else {
                continue
            }

            for axWindow in axWindows {
                let node = traverse(element: axWindow, depth: 0, maxDepth: maxDepth, path: "")
                roots.append(node)
            }
        }

        return roots
    }

    /// Format the AX tree as a human-readable indented string.
    static func formatTree(_ nodes: [AXNode], indent: Int = 0) -> String {
        var lines: [String] = []
        for node in nodes {
            let prefix = String(repeating: "  ", count: indent)
            let marker = node.isInteresting ? "*" : " "
            let titlePart = node.hasTitle ? " \"\(node.title)\"" : ""
            lines.append("\(prefix)\(marker) \(node.role)\(titlePart)")
            if !node.children.isEmpty {
                lines.append(formatTree(node.children, indent: indent + 1))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Generate a YAML config template from scanned nodes.
    ///
    /// Extracts "interesting" elements with titles and creates panel entries.
    static func generateConfig(appName: String, nodes: [AXNode]) -> String {
        var panels: [(name: String, path: String)] = []
        collectInteresting(nodes: nodes, into: &panels)

        var yaml = "app: \(appName)\npanels:\n"
        if panels.isEmpty {
            yaml += "  # No navigable panels detected. Add entries manually:\n"
            yaml += "  # - name: PanelName\n"
            yaml += "  #   ax_path: \"role index > role index\"\n"
        } else {
            for panel in panels {
                yaml += "  - name: \(panel.name)\n"
                yaml += "    ax_path: \"\(panel.path)\"\n"
            }
        }
        return yaml
    }

    // MARK: - Private

    private static func traverse(
        element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        path: String
    ) -> AXNode {
        let role = attribute(element, kAXRoleAttribute) ?? "Unknown"
        let title = attribute(element, kAXTitleAttribute)
            ?? attribute(element, kAXDescriptionAttribute)
            ?? ""

        let currentPath = path.isEmpty ? role : "\(path) > \(role)"
        let isInteresting = AXNode.interestingRoles.contains(role) && !title.isEmpty

        var children: [AXNode] = []
        if depth < maxDepth {
            children = getChildren(element).enumerated().map { index, child in
                let childRole = attribute(child, kAXRoleAttribute) ?? "Unknown"
                let indexedPath = path.isEmpty
                    ? "\(childRole) \(index)"
                    : "\(path) > \(childRole) \(index)"
                return traverse(
                    element: child,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    path: indexedPath
                )
            }
        }

        return AXNode(
            role: role,
            title: title,
            path: currentPath,
            children: children,
            isInteresting: isInteresting
        )
    }

    private static func attribute(_ element: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private static func getChildren(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &value
        )
        guard result == .success, let children = value as? [AXUIElement] else {
            return []
        }
        return children
    }

    private static func collectInteresting(
        nodes: [AXNode],
        into panels: inout [(name: String, path: String)]
    ) {
        for node in nodes {
            if node.isInteresting {
                panels.append((name: node.title, path: node.path))
            }
            collectInteresting(nodes: node.children, into: &panels)
        }
    }
}
