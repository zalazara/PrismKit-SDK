# PrismKit

SwiftUI layout measurement for design QA — and for AI agents that check a screen against a design.

PrismKit makes SwiftUI layout measurable at runtime: component bounds, sizes, internal padding, external spacing, safe-area guides, grid alignment, and design-system spacing-token validation. It ships with an MCP server, so an agent can read those same measurements and report what does not match the design.

## The problem

Reviewing SwiftUI spacing, padding, component sizes, and design-system compliance by eye is slow, error-prone, and hard to standardise. Comparing a build against a design means guessing frames, counting pixels in screenshots, or sprinkling temporary `GeometryReader`s.

Existing tools compare *images* and tell you something changed. PrismKit measures the live view tree in points, with semantic roles, so the answer is a number: `buyButton` has 14 pt of padding where the design says 16.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/zalazara/PrismKit.git", from: "1.0.0")
]
```

Requires iOS 15+ (also builds on macOS 12+). No dependencies. No private APIs.

## It compiles out of release builds

PrismKit walks the accessibility tree — which carries the labels and values of what is on screen, including text the user typed into fields — and can stream it to a companion over a local socket. None of that belongs in a shipping app, so **the entire collection, overlay and streaming layer is compiled out of release builds**. `measureScope` and `measure` return the view unchanged, no socket is opened, and the networking code is not even in the binary.

You do not need to wrap calls in `#if DEBUG`. Check `PrismKit.isEnabled` if you want to branch on the tool being available — showing a QA-only entry point, for instance.

## Basic usage

One modifier at the root of your app is enough:

```swift
import PrismKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .measureScope()
        }
    }
}
```

From there, every element assistive technologies expose becomes measurable — no per-view instrumentation. PrismKit reads the app's own accessibility tree, the same public protocol VoiceOver uses, so it sees most meaningful UI without you changing a line of layout code.

One prerequisite on iOS: the system only builds the accessibility tree while the accessibility flag is on. VoiceOver, the Accessibility Inspector and **UI tests** all set it. For a simulator:

```
xcrun simctl spawn booted defaults write com.apple.Accessibility ApplicationAccessibilityEnabled -bool true
xcrun simctl spawn booted defaults write com.apple.Accessibility AccessibilityEnabled -bool true
```

then relaunch the app.

### Optional enrichment

`measure(_:role:)` adds what the system cannot infer — which views form one component, and which part of it is the container versus the content, so internal padding can be derived:

```swift
HStack { icon; label }
    .measure("payButton", role: .content)
    .padding(12)
    .background(Capsule().fill(.blue))
    .measure("payButton", role: .container)
```

Measurements sharing a group name form one logical component. Roles: `container`, `content`, `title`, `subtitle`, `icon`, `image`, `background`, `custom("name")`.

Put these inside your design-system components rather than writing them per screen.

### Configuration

```swift
.measureScope(configuration: MeasureConfiguration(
    gridSize: 8,
    spacingTokens: [4, 8, 12, 16, 24, 32, 40, 48],
    showsGrid: true
))
```

Padding and spacing are checked against `spacingTokens`: valid values render green, invalid ones red with the nearest token, e.g. `13→12`.

## MCP server — checking screens with an agent

`prismkit-mcp` is a Model Context Protocol server (stdio). Point an agent at it and it can measure the running screen and check it against a design.

```json
{
  "mcpServers": {
    "prismkit": {
      "command": "/path/to/PrismKit/.build/release/prismkit-mcp"
    }
  }
}
```

Build it once with `swift build -c release`; `swift run` also works but re-resolves the package on every launch, which an agent experiences as a slow server.

### Tools

- **`get_measurements`** — every measured element with frames in scope and screen coordinates, roles, per-component padding with token validation, plus elements derived from the accessibility tree with zero instrumentation.
- **`measure_distance`** — gaps and edge/center deltas between two elements.
- **`check_alignment`** — which edges align exactly, near-miss alignments within a tolerance, and paddings or gaps that are not on the spacing scale.
- **`compare_to_design`** — checks the running screen against a design and returns the differences as numbers: position, size and wording per element, plus anything the design specifies that is not on screen.
- **`attach_design` / `detach_design`** — keeps a design attached so `compare_to_design` can be called repeatedly while you navigate and fix.
- **`get_design_tokens` / `set_design_tokens`** — the spacing scale every off-token judgement uses, and where it came from.
- **`list_simulators` / `capture_screenshot`** — simulator discovery and PNG captures.

### Any design source, not just one

PrismKit does not talk to Figma, Pencil, or any other design tool — the agent does. It reads the node with whichever design MCP it has connected and translates it into a neutral `DesignSpec`:

```json
{
  "source": "figma",
  "frame": { "width": 390, "height": 844 },
  "nodes": [
    {
      "id": "1:235",
      "name": "primaryButton",
      "match": "buyButton",
      "frame": { "x": 24, "y": 700, "width": 342, "height": 52 },
      "text": "Buy now"
    }
  ]
}
```

Adding a design source therefore needs no code here, and PrismKit never handles anyone's credentials.

**Pairing decides whether the result is trustworthy**, so it is reported. Nodes are paired by explicit identifier first, then by identical copy, then by geometric overlap — and findings carry which of those was used. A geometric pair is reported as a warning, never as a certainty, because a wrong pair produces a confident, well-formatted, invented defect.

### A team's spacing scale

Commit a `.prismkit.json` next to your code and the server, the app and CI all judge spacing by the same numbers:

```json
{
  "spacingTokens": [4, 8, 12, 16, 24, 32],
  "gridSize": 8
}
```

It is found by walking up from the working directory. Without one, judgements fall back to PrismKit's built-in scale — which is a guess at a design system, not yours, and `get_design_tokens` says so.

## Prism Inspector — the macOS companion

Measurements can also stream to **Prism Inspector**, a macOS app that inspects them on the Mac without any overlay covering the simulator: a view tree, a Figma-style canvas with click-to-select and distance measuring, an inspector, saved sessions, and the design check drawn over the live screen.

Streaming is on by default in `measureScope` and is a silent no-op when nothing is listening, so leaving it enabled costs nothing.

The companion is a separate, commercial product; PrismKit works fully without it.

## Example app

`Example/PrismKitExample.xcodeproj` is a runnable, instrumented sample:

```
open Example/PrismKitExample.xcodeproj
```

## Limitations

- **SwiftUI only.** No UIKit support in this version.
- **Element discovery comes from the accessibility tree.** That covers most meaningful UI, but not purely decorative views, and it needs the accessibility flag described above. Internal padding and semantic grouping still need the optional `measure(_:role:)` calls, because SwiftUI exposes no public runtime view graph to infer them from.
- **Not a general-purpose debugger.** For runtime property inspection use Lookin, Reveal, or the Xcode view debugger.
- **Simulator-first.** The companion workflow relies on the simulator sharing the Mac's loopback interface; physical devices would need discovery that is not built yet.
- Overlay labels for measurements scrolled offscreen can draw outside the visible viewport.

## License

[MIT](LICENSE). Embed it in your app, commercial or not.
