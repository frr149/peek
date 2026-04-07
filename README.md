# peek

Capture app and web UI screenshots without stealing focus.

## Why

AI coding assistants (Claude Code, Cursor, Copilot) are increasingly good at writing UI code — but they're blind. They can't see what they build. The developer becomes a human screenshot relay: "take a screenshot", "paste it here", "no, the other panel", "wait, let me switch windows..."

**peek** breaks this loop. It captures any macOS app window or web page silently, without stealing focus, without interrupting the developer's work. The AI sees its own output. The developer stays in flow.

## The visual REPL

peek turns UI development into a tight feedback loop for AI assistants:

```
┌─────────────────────────────────────────────────┐
│  1. AI edits SwiftUI/HTML code                  │
│  2. AI builds the app (xcodebuild / npm run)    │
│  3. AI runs: peek app ThinkLocal --panel Chat   │
│  4. AI sees the PNG → evaluates the result      │
│  5. AI decides: iterate (go to 1) or done       │
└─────────────────────────────────────────────────┘
        Developer doesn't intervene at all.
```

This is like a REPL, but for UI. The AI writes, sees, and iterates — autonomously.

## Designed for agents

Most CLI tools are designed for humans: colorful output, progress bars, decorative banners. peek is designed for LLM agents. Every design decision follows six Agent Experience (AX) principles:

**AX-1: Token-efficient output.** On success, peek prints the PNG path. Nothing else. No banners, no emojis, no "Successfully captured!" prose. One line, one token.

```bash
$ peek app ThinkLocal
/tmp/peek/ThinkLocal-20260407-183012.png
```

**AX-2: Zero mandatory flags.** Every command works with just the positional argument. `peek app Finder` captures Finder. `peek web http://localhost:3000` renders the page. No config required for basic use.

**AX-3: Tolerance (fuzzy matching).** Agents hallucinate app names. peek handles it silently:

```bash
$ peek app "think local"    # matches "ThinkLocal"
$ peek app thinklocal       # matches "ThinkLocal"
$ peek app think            # matches "ThinkLocal" (substring)
```

Normalization: case-insensitive, strips spaces and hyphens, falls back to substring matching.

**AX-4: Stable output contract.** The output format is a versioned contract. Agents parse it. `peek list` outputs tab-separated `<App>\t<Windows>\t<WxH>`. `peek scan` outputs YAML. These formats never change without a major version bump.

**AX-5: Actionable errors.** When something fails, peek tells the agent what to do:

```bash
$ peek app ThinkLocal --panel Chat
Error: No config for "ThinkLocal". Generate one with: peek scan ThinkLocal --generate-config > ~/.config/peek/ThinkLocal.yml
```

**AX-6: One surface.** Unlike tools that need separate human/machine interfaces, peek's output (a file path) is natively useful to both humans (open the PNG) and agents (read the path). No dual surface needed.

### Why this matters

An agent using peek spends 1 token on output parsing. An agent using a verbose CLI spends 15+ tokens filtering noise. Multiply by hundreds of captures in a design iteration session, and token-efficient design becomes a real cost advantage.

## Design review workflow

peek pairs with a **design review skill** (included below) to give AI assistants access to a panel of design experts. The full autonomous workflow:

```
┌──────────────────────────────────────────────────────────┐
│  1. AI captures all panels:  peek app MyApp --all        │
│  2. AI selects 3 experts from a pool of 6:               │
│     Tufte · Krug · Jobs · Cooper · Nielsen · Ive         │
│  3. Each expert reviews the screenshots independently    │
│  4. Experts debate in a roundtable (max 8 rounds)        │
│  5. AI produces a prioritized action report              │
│  6. Developer reviews only the final recommendations     │
│     and approves/rejects each one                        │
│  7. AI implements approved changes                       │
│  8. AI captures again → verifies the fix → done          │
└──────────────────────────────────────────────────────────┘
```

The developer enters the loop **only at step 6** — to make decisions, not to take screenshots. Everything mechanical is handled by peek + the AI.

### The expert pool

| Expert        | Focus                                  | Best for                                  |
| ------------- | -------------------------------------- | ----------------------------------------- |
| Edward Tufte  | Data density, information design       | Charts, dashboards, data-heavy views      |
| Steve Krug    | Usability, "don't make me think"       | Navigation, forms, onboarding flows       |
| Steve Jobs    | Simplicity, emotional design           | Overall layout, first impressions, polish |
| Alan Cooper   | Interaction design, eliminating excise | Workflows, multi-step processes, tooling  |
| Jakob Nielsen | Heuristic evaluation, accessibility    | Error states, help text, edge cases       |
| Jony Ive      | Visual refinement, material honesty    | Typography, spacing, visual hierarchy     |

For each review, the AI selects the 3 most relevant experts based on what's being reviewed. A data dashboard gets Tufte; a navigation redesign gets Krug + Cooper.

### Including the skill in your project

The design review skill lives in Claude Code's skill system. To use it with peek:

1. Copy `skills/design-review/SKILL.md` to `~/.claude/skills/design-review/SKILL.md`
2. The skill auto-detects peek and uses it for screenshots
3. Invoke with `/design-review` in Claude Code

See [`skills/design-review/SKILL.md`](skills/design-review/SKILL.md) for the full skill definition.

## Features

- **`peek app <name>`** — Capture a running macOS app window, even behind other windows
- **`peek app <name> --panel <panel>`** — Navigate to a panel via Accessibility API, then capture
- **`peek app <name> --all`** — Capture all configured panels in one pass
- **`peek web <url>`** — Render a URL headlessly with WebKit and capture
- **`peek scan <name>`** — Discover an app's accessibility tree for config generation
- **`peek list`** — List running apps with capturable windows

## Install

### Homebrew

```bash
brew tap frr149/tools
brew install frr149/tools/peek
```

### From source

```bash
git clone https://github.com/frr149/peek.git
cd peek
make install
```

## Usage

```bash
# Capture a window (saves to /tmp/peek/)
peek app ThinkLocal

# Capture a specific panel
peek app ThinkLocal --panel Schemas

# Capture all configured panels
peek app ThinkLocal --all

# Capture a web page
peek web http://localhost:3000

# Discover navigable panels and generate config
peek scan ThinkLocal --generate-config > ~/.config/peek/ThinkLocal.yml

# List capturable windows
peek list
```

## Configuration

Panel definitions live in `~/.config/peek/<AppName>.yml`:

```yaml
app: ThinkLocal
panels:
  - name: Chat
    ax_path: "outline 1 > row 2"
  - name: Image Studio
    ax_path: "outline 1 > row 3"
  - name: Schemas
    ax_path: "outline 1 > row 4"
  - name: Tools Lab
    ax_path: "outline 1 > row 5"
  - name: Model Info
    ax_path: "outline 1 > row 6"
```

Generate a config template automatically:

```bash
peek scan ThinkLocal --generate-config
```

## How it works

- **Native apps:** Uses ScreenCaptureKit (`SCScreenshotManager`) to capture a specific window by ID — no focus stealing, works even when the window is behind others. Retina-resolution by default.
- **AX navigation:** Uses the macOS Accessibility API (`AXUIElement`) to interact with app controls without bringing the window to front.
- **Web pages:** Loads the URL in a headless `WKWebView`, waits for page load, and captures the rendered output. No browser needed.

## Requirements

- macOS 15.0+
- Screen Recording permission (System Settings → Privacy → Screen Recording)
- Accessibility permission (System Settings → Privacy → Accessibility)

Both permissions are granted to the terminal app (Terminal.app, iTerm2, etc.), not to peek itself.

## License

MIT — see [LICENSE](LICENSE).
