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
- `brew install frr149/peek/peek` works end-to-end

## Non-goals for v1.0

- Visual diffing / regression testing
- Video capture
- AI-powered analysis (that's the design-review skill's job)
- Cross-platform (Linux, Windows) — macOS only, by design

---

## Agent Experience (AX) principles

peek's primary consumer is an LLM agent, not a human. Every design decision must
prioritize the agent's ability to use peek reliably, with minimal tokens, and
without hallucinating flags or misinterpreting output.

### AX-1: Token-efficient output

Output only what the agent needs to proceed. No banners, no colors, no decorative
prose. On success, print the PNG path — nothing else. On `--all`, one path per line.

```
# Good (1 token)
/tmp/peek/ThinkLocal-Chat-20260407-183012.png

# Bad (15 tokens)
✅ Successfully captured window "ThinkLocal" panel "Chat"
   Saved to: /tmp/peek/ThinkLocal-Chat-20260407-183012.png
```

### AX-2: Zero mandatory flags

Every command must work with just the positional argument:

- `peek app Finder` — works, captures main window
- `peek web http://localhost:3000` — works, default viewport
- `peek list` — works, no config needed
- `peek scan Finder` — works, default depth

### AX-3: Tolerance (fuzzy app matching)

Agents hallucinate app names. peek must normalize silently:

- `peek app "Think Local"` → matches "ThinkLocal"
- `peek app thinklocal` → matches "ThinkLocal"
- `peek app think` → matches "ThinkLocal" if unambiguous
- Multiple matches → list candidates and exit with code 1

Normalization: case-insensitive, ignore spaces/hyphens, substring match as fallback.

### AX-4: Stable output contract

The output format is a contract. Agents parse it. Never change it without bumping
the major version.

- **Success:** print the absolute path(s) to PNG file(s), one per line, to stdout
- **Error:** print a single-line error to stderr, exit with non-zero code
- **List:** tabular format: `<AppName>\t<WindowCount>\t<Width>x<Height>`
- **Scan:** YAML to stdout (parseable, not just pretty-printed)

### AX-5: Actionable errors

When something fails, tell the agent what to do — don't just describe the failure.

```
# Good
Error: "ThinkLocal" is not running. Start it with: open ~/Applications/ThinkLocal.app

# Bad
Error: Could not find window for application "ThinkLocal"
```

If config is missing for `--panel`/`--all`:

```
Error: No config for "ThinkLocal". Generate one with: peek scan ThinkLocal --generate-config > ~/.config/peek/ThinkLocal.yml
```

### AX-6: No dual surface needed

Unlike lql/driftkit, peek does not need a separate `peekl`. The tool is inherently
agent-first: its output is a PNG file path, not human-readable text. Humans use
the PNG viewer; agents use the path. One surface serves both.

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
- Fuzzy matching: case-insensitive, ignores spaces/hyphens (AX-3)
- Substring match as fallback when exact match fails
- Multiple matches returns all candidates (caller decides)

**Tests**:

- `testDiscoverFinderWindow` — Finder is always running
- `testDiscoverNonExistentAppReturnsEmpty`
- `testDiscoveredWindowHasPositionAndSize`
- `testFuzzyMatchIgnoresCase`
- `testFuzzyMatchIgnoresSpaces`
- `testSubstringMatchAsFallback`

---

### T02: Window capture [sonnet]

**Objective**: Capture a window's pixels to a PNG file using ScreenCaptureKit, without stealing focus.
**Depends on**: T01.
**Deliverable**: `Sources/Peek/Capture/WindowCapture.swift`

**Acceptance criteria**:

- Captures a specific window by CGWindowID via ScreenCaptureKit
- Output is a valid PNG file with non-zero dimensions
- Does NOT bring the target window to front
- Does NOT activate the target application
- Handles Retina displays (output is @2x resolution)
- Returns the file path of the saved PNG
- stdout prints only the path (AX-1)

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
- With `--all`: `/tmp/peek/<AppName>/<Panel>.png` (no timestamp, overwrite)
- Creates `/tmp/peek/` if it doesn't exist
- Timestamp format: `YYYYMMDD-HHmmss`

**Tests**:

- `testDefaultPathContainsAppName`
- `testPanelPathContainsPanelName`
- `testCustomOutputPathUsedAsIs`
- `testTimestampFormatIsCorrect`
- `testAllModePutsPanelsInSubdirectory`

---

### T04: List command [haiku]

**Objective**: List all running apps with capturable windows.
**Depends on**: T01.
**Deliverable**: `Sources/Peek/Commands/ListCommand.swift` (replace stub)

**Acceptance criteria**:

- Lists app name, window count, and main window size
- Filters out system windows (menubar, dock, etc.)
- Sorted alphabetically by app name
- Tab-separated format: `<AppName>\t<WindowCount>\t<Width>x<Height>` (AX-4)
- No header row, no decorations

**Tests**:

- `testListIncludesFinder`
- `testListExcludesSystemWindows`
- `testListOutputIsSorted`
- `testListOutputIsTabSeparated`

---

### T05: App capture command [sonnet]

**Objective**: Wire up the `peek app <name>` command end-to-end.
**Depends on**: T01, T02, T03.
**Deliverable**: `Sources/Peek/Commands/AppCommand.swift` (replace stub)

**Acceptance criteria**:

- `peek app Finder` produces a PNG of the Finder window, prints path to stdout
- `peek app Finder --output /tmp/test.png` saves to the specified path
- If app is not running, prints actionable error to stderr and exits with code 1 (AX-5)
- If multiple windows exist, captures the main (largest) window
- If fuzzy match finds multiple apps, lists candidates and exits with code 1
- stdout contains ONLY the output path on success (AX-1)

**Tests**:

- `testAppCommandCapturesFinder`
- `testAppCommandWithCustomOutput`
- `testAppCommandNonExistentAppExitsWithError`
- `testAppCommandAmbiguousMatchListsCandidates`

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
- Default output: human-readable indented tree to stdout
- With `--generate-config`, outputs valid YAML to stdout (AX-4)

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
- Fuzzy matches config filename (AX-3): `ThinkLocal.yml` matches query "thinklocal"
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
- Missing file returns nil (not a crash)
- Malformed YAML → descriptive error to stderr (AX-5)

**Tests**:

- `testParseValidConfig`
- `testParseMissingFileReturnsNil`
- `testParseMalformedYAMLThrowsDescriptiveError`
- `testPanelConfigHasNameAndPath`
- `testFuzzyConfigFileLookup`

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
- Returns success/failure with descriptive error to stderr (AX-5)

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
- `--all` prints one path per line to stdout (AX-4)
- If config file is missing for `--panel`/`--all`, prints actionable error pointing to `peek scan` (AX-5)
- Panel name matching is fuzzy (AX-3): `--panel schemas` matches "Schemas"

**Tests**:

- `testPanelFlagNavigatesBeforeCapture`
- `testAllFlagCapturesEveryConfiguredPanel`
- `testAllWithoutConfigShowsHelpfulError`
- `testPanelNameFuzzyMatching`

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
- stdout prints only the path on success (AX-1)
- Errors to stderr with suggestion (AX-5)

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
- If app is not running, prints actionable error (AX-5)

**Tests**:

- `testScanCommandOutputsTree`
- `testScanCommandGenerateConfigOutputsYAML`
- `testScanCommandRespectsDepth`

---

### T12: Homebrew release automation [sonnet]

**Objective**: Automate the full release pipeline from git tag to `brew install`.
**Depends on**: T05.
**Deliverable**: `.github/workflows/release.yml`, Makefile targets, tap repo

**Acceptance criteria**:

- `git tag v1.0.0 && git push --tags` triggers GitHub Actions workflow
- Workflow builds universal binary (arm64 + x86_64)
- Workflow creates GitHub Release with tarball artifact
- Workflow updates `frr149/homebrew-peek` tap with new formula
- `brew install frr149/peek/peek` installs the latest release
- `peek --version` shows the correct version from the git tag

**Tests**:

- `testVersionFlagShowsVersion`
- Manual: `brew install frr149/peek/peek && peek list` works

---

### T13: Integration test with ThinkLocal [sonnet]

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

### T14: Update README with AX principles [haiku]

**Objective**: Reflect Agent Experience design principles in the README.
**Depends on**: T05 (needs concrete examples from working CLI).
**Deliverable**: `README.md` (update)

**Acceptance criteria**:

- New section "Designed for agents" between "The visual REPL" and "Design review workflow"
- Explains the 6 AX principles with concrete peek examples (not abstract theory)
- Shows fuzzy matching in action: `peek app "think local"` → matches ThinkLocal
- Shows token-efficient output: just the path, nothing else
- Shows actionable errors: what went wrong + what to do
- Mentions ScreenCaptureKit (not deprecated CGWindowListCreateImage)
- Tone: technical, opinionated, HN-ready — not marketing fluff

**Tests**:

- N/A (documentation)

---

### T15: Update blog post with AX angle [haiku]

**Objective**: Add Agent Experience as the technical differentiator in the HN blog post.
**Depends on**: T14 (README is the source of truth).
**Deliverable**: Blog post update in frr.dev repo

**Acceptance criteria**:

- New section after "El REPL visual" explaining AX principles
- Frame it as "most CLIs are designed for humans — peek is designed for agents"
- Concrete before/after examples: verbose human output vs token-efficient agent output
- Mention tolerance architecture: agents hallucinate flags, peek handles it
- Reference lql and driftkit as prior art (same author, same philosophy)
- Keep the opinionated HN tone — this is a design stance, not a feature list

**Tests**:

- N/A (documentation)

---

## Implementation order

```
T01 ──→ T02 ──→ T05 ──→ T09 ──→ T13
  │              ↑        ↑
  ├──→ T04       │        │
  │              T03      T08
  └──→ T06 ──→ T08       ↑
       │                  │
       └──→ T11           T07

T03 (independent)
T07 (independent)
T10 (independent, depends only on T03)
T12 (independent, needs only working binary)
T14 → T15 (docs, after T05 for concrete examples)
```

**Critical path**: T01 → T02 → T05 → T09 → T13

**Parallelizable**:

- T03, T07 can start immediately (no dependencies)
- T04, T06 can start after T01
- T10 can start after T03
- T12 can start once T05 is done (needs a working binary to test)

## Dispatch model assignments

| Task | Model  | Rationale                                                |
| ---- | ------ | -------------------------------------------------------- |
| T01  | haiku  | Straightforward CGWindowList wrapper + fuzzy matching    |
| T02  | sonnet | ScreenCaptureKit, Retina handling                        |
| T03  | haiku  | Simple path string logic                                 |
| T04  | haiku  | Format and filter window list                            |
| T05  | sonnet | Command wiring, error handling, AX compliance            |
| T06  | opus   | AX tree traversal is complex, unfamiliar API             |
| T07  | haiku  | YAML parsing with Yams, simple Codable                   |
| T08  | opus   | AX navigation without focus stealing is the hardest part |
| T09  | sonnet | Orchestration of existing components                     |
| T10  | sonnet | WKWebView lifecycle, async/await bridging                |
| T11  | haiku  | Wire existing scanner to command                         |
| T12  | sonnet | GitHub Actions, Makefile, Homebrew formula               |
| T13  | sonnet | Integration test design, conditional skip                |
| T14  | haiku  | README update, straightforward writing                   |
| T15  | haiku  | Blog post update, same content adapted                   |
