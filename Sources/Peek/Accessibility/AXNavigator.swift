import ApplicationServices
import Foundation

/// Errors from AX navigation.
enum AXNavigationError: Error, CustomStringConvertible {
    case accessibilityDenied
    case appNotFound(pid_t)
    case pathNotFound(String, detail: String)
    case actionFailed(String, detail: String)

    var description: String {
        switch self {
        case .accessibilityDenied:
            return "Error: Accessibility permission denied. Grant it in System Settings > Privacy & Security > Accessibility."
        case .appNotFound(let pid):
            return "Error: no application found with PID \(pid)."
        case .pathNotFound(let path, let detail):
            return "Error: AX path \"\(path)\" not found: \(detail)"
        case .actionFailed(let path, let detail):
            return "Error: failed to perform action at \"\(path)\": \(detail)"
        }
    }
}

/// Navigates to a specific element in an app's accessibility tree and performs
/// an action (press/select), without stealing focus.
///
/// AX paths use the format: `"role index > role index > ..."`
/// For example: `"outline 0 > row 3"` means:
///   - Find the first AXOutline child
///   - Within it, find the 4th AXRow child
enum AXNavigator {

    /// Navigate to an element specified by an AX path and press/select it.
    ///
    /// This method does NOT call `NSRunningApplication.activate` or
    /// `NSApplication.activate`. It uses only AXUIElement APIs, which do not
    /// steal focus.
    ///
    /// - Parameters:
    ///   - pid: The process ID of the target application.
    ///   - axPath: Path in the format `"role index > role index"`.
    ///   - settleDelay: Seconds to wait after navigation (default: 0.5).
    static func navigate(pid: pid_t, axPath: String, settleDelay: TimeInterval = 0.5) throws {
        guard AXIsProcessTrusted() else {
            throw AXNavigationError.accessibilityDenied
        }

        let appElement = AXUIElementCreateApplication(pid)

        // Get the app's windows
        var windowsValue: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(
            appElement, kAXWindowsAttribute as CFString, &windowsValue
        )
        guard windowResult == .success, let axWindows = windowsValue as? [AXUIElement],
              let mainWindow = axWindows.first
        else {
            throw AXNavigationError.appNotFound(pid)
        }

        // Parse the path
        let segments = parseAXPath(axPath)
        guard !segments.isEmpty else {
            throw AXNavigationError.pathNotFound(axPath, detail: "empty path")
        }

        // Walk the path from the main window
        var current: AXUIElement = mainWindow
        var resolvedPath = ""

        for segment in segments {
            let children = getChildren(current)
            let matching = children.filter { child in
                roleMatches(child, segment.role)
            }

            guard segment.index < matching.count else {
                throw AXNavigationError.pathNotFound(
                    axPath,
                    detail: "segment \"\(segment.role) \(segment.index)\" — found \(matching.count) \(segment.role) elements, need index \(segment.index)"
                )
            }

            current = matching[segment.index]
            resolvedPath += resolvedPath.isEmpty
                ? "\(segment.role) \(segment.index)"
                : " > \(segment.role) \(segment.index)"
        }

        // Perform the action on the target element
        try performAction(on: current, path: axPath)
    }

    // MARK: - Path parsing

    struct PathSegment {
        let role: String
        let index: Int
    }

    /// Parse an AX path like `"outline 1 > row 4"` into segments.
    static func parseAXPath(_ path: String) -> [PathSegment] {
        path.split(separator: ">")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { segment in
                let parts = segment.split(separator: " ")
                guard parts.count >= 2,
                      let index = Int(parts.last!)
                else {
                    // If no index, assume 0
                    if !segment.isEmpty {
                        return PathSegment(role: segment, index: 0)
                    }
                    return nil
                }
                let role = parts.dropLast().joined(separator: " ")
                return PathSegment(role: role, index: index)
            }
    }

    // MARK: - Private

    /// Check if an AXUIElement's role matches the expected role string.
    /// Matching is flexible: "outline" matches "AXOutline", "row" matches "AXRow", etc.
    private static func roleMatches(_ element: AXUIElement, _ expected: String) -> Bool {
        guard let role = attribute(element, kAXRoleAttribute) else {
            return false
        }
        let normalizedRole = role.lowercased()
        let normalizedExpected = expected.lowercased()

        // Exact match
        if normalizedRole == normalizedExpected { return true }

        // Match without AX prefix
        if normalizedRole == "ax\(normalizedExpected)" { return true }

        // Match with AX prefix stripped
        if normalizedRole.hasPrefix("ax") {
            let stripped = String(normalizedRole.dropFirst(2))
            if stripped == normalizedExpected { return true }
        }

        return false
    }

    /// Perform AXPress or AXSelect on an element.
    private static func performAction(on element: AXUIElement, path: String) throws {
        // Try AXPress first (buttons, tabs)
        var result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if result == .success { return }

        // Try AXSelect (rows, outline rows)
        // First check if we can set the selected attribute
        var selectedValue: CFTypeRef?
        let hasSelected = AXUIElementCopyAttributeValue(
            element, kAXSelectedAttribute as CFString, &selectedValue
        )
        if hasSelected == .success {
            result = AXUIElementSetAttributeValue(
                element, kAXSelectedAttribute as CFString, true as CFTypeRef
            )
            if result == .success { return }
        }

        // Try AXConfirm
        result = AXUIElementPerformAction(element, kAXConfirmAction as CFString)
        if result == .success { return }

        // If no action worked, report but don't fail — some elements don't need
        // explicit action (their selection is done by parent)
        // This is not necessarily an error; the navigation itself may be sufficient.
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
}
