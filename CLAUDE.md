# CLAUDE.md — peek

## What is peek

A macOS CLI tool that captures screenshots of native apps and web pages without stealing focus. Designed as a visual feedback loop for AI coding assistants.

## Stack

- **Language:** Swift 6.0
- **Build:** Swift Package Manager (CLI tool — SPM is the right choice here)
- **CLI parsing:** swift-argument-parser
- **Config:** Yams (YAML)
- **macOS frameworks:** CoreGraphics (window capture), ApplicationServices (AXUIElement), WebKit (headless web), AppKit (NSImage)

## Architecture

```
Sources/Peek/
├── Peek.swift                 # @main entry point, command registry
├── Commands/                  # One file per subcommand
│   ├── AppCommand.swift       # peek app <name>
│   ├── WebCommand.swift       # peek web <url>
│   ├── ScanCommand.swift      # peek scan <name>
│   └── ListCommand.swift      # peek list
├── Capture/                   # Core capture logic
│   ├── WindowCapture.swift    # CGWindowListCreateImage wrapper
│   └── WebCapture.swift       # WKWebView headless renderer
├── Accessibility/             # AX tree navigation
│   ├── AXScanner.swift        # AXUIElement tree traversal
│   └── AXNavigator.swift      # Navigate to panels using AX paths
└── Config/                    # Configuration
    └── PeekConfig.swift       # YAML parsing, per-app panel definitions
```

## Core principles

1. **Never steal focus.** All capture uses `CGWindowListCreateImage` with a specific window ID. Never `NSApplication.activate` or `osascript 'tell app to activate'`.
2. **Zero daemon.** No background process, no server. Just a CLI binary.
3. **Config is optional.** `peek app X` works with zero config. Config only needed for `--panel` and `--all`.
4. **Output is a PNG.** Default path: `/tmp/peek/<AppName>[-panel]-<timestamp>.png`. Override with `--output`.

## Build and test

```bash
make build          # Release build
make test           # Run tests
make install        # Install to /usr/local/bin
make run ARGS="list"  # Run with arguments
```

## Permissions

peek needs two macOS permissions:

- **Screen Recording** — for CGWindowListCreateImage (captures window pixels)
- **Accessibility** — for AXUIElement (navigates UI elements)

Both are granted per-terminal, not per-binary. If running from Terminal.app or iTerm2, the terminal app needs the permissions.

## Language

All code, comments, docs, and user-facing text in **English** (public repo).

## Release workflow

```bash
git tag v0.1.0
make gh-release     # Builds universal binary, creates GitHub release
make bump-formula   # Updates Homebrew tap
```
