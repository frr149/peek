# peek v1.0 — Product Requirements Document

## Vision

A macOS CLI that gives AI coding assistants (and developers) a visual feedback loop: capture screenshots of native apps and web pages without stealing focus, interrupting workflow, or requiring manual intervention.

## Target user

1. **Primary:** AI coding assistants (Claude Code, Cursor, Copilot) building UI — need to see what they create
2. **Secondary:** Developers who want quick visual checks without Cmd-Tab

## Success criteria

- Claude Code can capture all 5 ThinkLocal panels in <5 seconds total, without the developer noticing
- `peek app ThinkLocal --all` produces 5 PNGs that accurately reflect the current UI state
- `peek web http://localhost:3000` renders and captures a page without any visible browser window

## Non-goals for v1.0

- Visual diffing / regression testing
- Linux or Windows support
- Video capture
- AI-powered analysis (that's the design-review skill's job)
- Homebrew formula automation (manual release is fine for v1.0)

---

## Tasks

### T01: Window discovery [haiku]

**Objective**: Find a running app's window ID by name using CoreGraphics.
**Depends on**: Nothing.
**Deliverable**: `Sources/Peek/Capture/WindowDiscovery.swift`

**Acceptance criteria**:

- Given app name "Finder", returns at least one window ID
- Given app name "NonExistentApp12345", returns empty array
- Returns window ID, title, position, size, and owner name
- Works for windows that are behind other windows (not frontmost)

**Tests**:

- `testDiscoverFinderWindow` — Finder is always running
- `testDiscoverNonExistentAppReturnsEmpty`
- `testDiscoveredWindowHasPositionAndSize`

---

### T02: Window capture [sonnet]

**Objective**: Capture a window's pixels to a PNG file using CGWindowListCreateImage, without stealing focus.
**Depends on**: T01.
**Deliverable**: `Sources/Peek/Capture/WindowCapture.swift`

**Acceptance criteria**:

- Captures a specific window by CGWindowID
- Output is a valid PNG file with non-zero dimensions
- Does NOT bring the target window to front
- Does NOT activate the target application
- Handles Retina displays (output is @2x resolution)
- Returns the file path of the saved PNG

**Tests**:

- `testCaptureFinderWindowProducesPNG`
- `testCapturedImageHasNonZeroDimensions`
- `testCaptureDoesNotChangeActiveApplication`
- `testOutputPathMatchesRequested`

---

### T03: Output path management [haiku]

**Objective**: Generate consistent, predictable output paths for captured screenshots.
**Depends on**: Nothing.
**Deliverable**: `Sources/Peek/Config/OutputPath.swift`

**Acceptance criteria**:

- Default: `/tmp/peek/<AppName>-<timestamp>.png`
- With panel: `/tmp/peek/<AppName>-<panel>-<timestamp>.png`
- With `--output`: use exact path provided
- Creates `/tmp/peek/` if it doesn't exist
- Timestamp format: `YYYYMMDD-HHmmss`

**Tests**:

- `testDefaultPathContainsAppName`
- `testPanelPathContainsPanelName`
- `testCustomOutputPathUsedAsIs`
- `testTimestampFormatIsCorrect`

---

### T04: List command [haiku]

**Objective**: List all running apps with capturable windows.
**Depends on**: T01.
**Deliverable**: `Sources/Peek/Commands/ListCommand.swift` (replace stub)

**Acceptance criteria**:

- Lists app name, window count, and main window size
- Filters out system windows (menubar, dock, etc.)
- Sorted alphabetically by app name
- Outputs clean tabular format to stdout

**Tests**:

- `testListIncludesFinder`
- `testListExcludesSystemWindows`
- `testListOutputIsSorted`

---

### T05: App capture command [sonnet]

**Objective**: Wire up the `peek app <name>` command end-to-end.
**Depends on**: T01, T02, T03.
**Deliverable**: `Sources/Peek/Commands/AppCommand.swift` (replace stub)

**Acceptance criteria**:

- `peek app Finder` produces a PNG of the Finder window
- `peek app Finder --output /tmp/test.png` saves to the specified path
- If the app is not running, prints a clear error and exits with code 1
- If multiple windows exist, captures the main (largest) window
- Prints the output path to stdout on success

**Tests**:

- `testAppCommandCapturesFinder`
- `testAppCommandWithCustomOutput`
- `testAppCommandNonExistentAppExitsWithError`

---

### T06: AX tree scanner [opus]

**Objective**: Traverse an app's accessibility tree to discover navigable elements (sidebar items, tabs, toolbar buttons).
**Depends on**: T01.
**Deliverable**: `Sources/Peek/Accessibility/AXScanner.swift`

**Acceptance criteria**:

- Given an app name, returns a tree of AX elements with role, title, and path
- Discovers clickable elements: buttons, rows, tabs, menu items
- Limits depth to prevent infinite traversal (default: 4 levels)
- Identifies "interesting" elements (those with titles that look like panel/tab names)
- Outputs human-readable tree to stdout
- With `--generate-config`, outputs a YAML template

**Tests**:

- `testScanFinderReturnsNonEmptyTree`
- `testScanRespectsDepthLimit`
- `testGenerateConfigOutputsValidYAML`

---

### T07: YAML config system [haiku]

**Objective**: Parse per-app panel configuration from YAML files.
**Depends on**: Nothing.
**Deliverable**: `Sources/Peek/Config/PeekConfig.swift`

**Acceptance criteria**:

- Reads `~/.config/peek/<AppName>.yml`
- Falls back to `.peek.yml` in current directory
- Config structure:
  ```yaml
  app: ThinkLocal
  panels:
    - name: Chat
      ax_path: "outline 1 > row 2"
    - name: Schemas
      ax_path: "outline 1 > row 4"
  ```
- Returns typed `PeekConfig` with `[PanelConfig]`
- Graceful error if file doesn't exist (not a crash)

**Tests**:

- `testParseValidConfig`
- `testParseMissingFileReturnsNil`
- `testParseMalformedYAMLThrowsDescriptiveError`
- `testPanelConfigHasNameAndPath`

---

### T08: AX navigation [opus]

**Objective**: Navigate to a specific panel in an app using the Accessibility API, without stealing focus.
**Depends on**: T06, T07.
**Deliverable**: `Sources/Peek/Accessibility/AXNavigator.swift`

**Acceptance criteria**:

- Given an AX path like `"outline 1 > row 4"`, navigates to that element
- Performs AXPress action on the target element
- Does NOT call `NSApplication.activate` or `NSRunningApplication.activate`
- Waits for UI to settle after navigation (configurable, default 0.5s)
- Returns success/failure with descriptive error

**Tests**:

- `testNavigateToFinderSidebarItem`
- `testNavigateWithInvalidPathReturnsError`
- `testNavigationDoesNotStealFocus`

---

### T09: Panel capture (--panel and --all) [sonnet]

**Objective**: Add `--panel` and `--all` flags to the app command.
**Depends on**: T05, T07, T08.
**Deliverable**: `Sources/Peek/Commands/AppCommand.swift` (extend)

**Acceptance criteria**:

- `peek app ThinkLocal --panel Schemas` navigates then captures
- `peek app ThinkLocal --all` captures every panel in the config
- `--all` saves to `/tmp/peek/<AppName>/<Panel>.png` (one file per panel)
- If config file is missing for `--panel`/`--all`, prints helpful error pointing to `peek scan`
- Prints summary: captured N panels, saved to <directory>

**Tests**:

- `testPanelFlagNavigatesBeforeCapture`
- `testAllFlagCapturesEveryConfiguredPanel`
- `testAllWithoutConfigShowsHelpfulError`

---

### T10: Web capture [sonnet]

**Objective**: Capture a web page headlessly using WKWebView.
**Depends on**: T03.
**Deliverable**: `Sources/Peek/Capture/WebCapture.swift`, update `WebCommand.swift`

**Acceptance criteria**:

- Loads URL in a headless WKWebView (no visible window)
- Waits for `didFinish` navigation callback + optional delay
- Captures the rendered page to PNG
- Supports `--width` and `--height` for viewport size
- Supports `--wait` for extra delay (SPAs)
- Handles load errors gracefully (timeout, DNS failure, etc.)
- Timeout: 30 seconds max

**Tests**:

- `testCaptureLocalHTMLFile` — use a file:// URL with known content
- `testCaptureRespectsViewportSize`
- `testCaptureWithWaitDelay`
- `testCaptureInvalidURLReturnsError`
- `testCaptureTimeoutReturnsError`

---

### T11: Scan command wiring [haiku]

**Objective**: Wire up the `peek scan` command end-to-end.
**Depends on**: T06.
**Deliverable**: `Sources/Peek/Commands/ScanCommand.swift` (replace stub)

**Acceptance criteria**:

- `peek scan Finder` prints the AX tree
- `peek scan Finder --generate-config` outputs valid YAML to stdout
- `peek scan Finder --depth 2` limits traversal depth
- If app is not running, prints clear error

**Tests**:

- `testScanCommandOutputsTree`
- `testScanCommandGenerateConfigOutputsYAML`
- `testScanCommandRespectsDepth`

---

### T12: Integration test with ThinkLocal [sonnet]

**Objective**: End-to-end test that captures all ThinkLocal panels.
**Depends on**: T09.
**Deliverable**: `Tests/PeekTests/ThinkLocalIntegrationTests.swift`

**Acceptance criteria**:

- Requires ThinkLocal to be running (skip if not)
- Generates config with `peek scan ThinkLocal --generate-config`
- Captures all panels with `peek app ThinkLocal --all`
- Verifies each PNG exists and has non-zero file size
- Verifies capture completes in <10 seconds total
- Does not steal focus during the entire test

**Tests**:

- `testCaptureAllThinkLocalPanels`
- `testCaptureCompletesUnderTenSeconds`
- `testFocusNotStolenDuringCapture`

---

## Implementation order

```
T01 ──→ T02 ──→ T05 ──→ T09
  │              ↑        ↑
  ├──→ T04       │        │
  │              T03      T08 ──→ T12
  └──→ T06 ──→ T08       ↑
       │                  │
       └──→ T11           T07

T03 (independent)
T07 (independent)
T10 (independent, depends only on T03)
```

**Critical path**: T01 → T02 → T05 → T09 → T12

**Parallelizable**:

- T03, T07 can start immediately (no dependencies)
- T04, T06 can start after T01
- T10 can start after T03

## Dispatch model assignments

| Task | Model  | Rationale                                                |
| ---- | ------ | -------------------------------------------------------- |
| T01  | haiku  | Straightforward CGWindowList wrapper                     |
| T02  | sonnet | CGImage manipulation, Retina handling                    |
| T03  | haiku  | Simple path string logic                                 |
| T04  | haiku  | Format and filter window list                            |
| T05  | sonnet | Command wiring, error handling                           |
| T06  | opus   | AX tree traversal is complex, unfamiliar API             |
| T07  | haiku  | YAML parsing with Yams, simple Codable                   |
| T08  | opus   | AX navigation without focus stealing is the hardest part |
| T09  | sonnet | Orchestration of existing components                     |
| T10  | sonnet | WKWebView lifecycle, async/await bridging                |
| T11  | haiku  | Wire existing scanner to command                         |
| T12  | sonnet | Integration test design, conditional skip                |
