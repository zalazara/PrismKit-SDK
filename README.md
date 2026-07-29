# PrismKit

SwiftUI layout measurement for design QA — and for AI agents that check a screen against a design.

PrismKit makes SwiftUI layout measurable at runtime: component bounds, sizes, internal padding, external spacing, safe-area guides, grid alignment, and design-system spacing-token validation. Its companion app, [Prism Inspector](https://zalazara.github.io/PrismKit-SDK/), reads those measurements on a Mac and exposes them over MCP, so an agent can report what does not match the design.

## The problem

Reviewing SwiftUI spacing, padding, component sizes, and design-system compliance by eye is slow, error-prone, and hard to standardise. Comparing a build against a design means guessing frames, counting pixels in screenshots, or sprinkling temporary `GeometryReader`s.

Existing tools compare *images* and tell you something changed. PrismKit measures the live view tree in points, with semantic roles, so the answer is a number: `buyButton` has 14 pt of padding where the design says 16.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/zalazara/PrismKit-SDK.git", from: "0.2.0")
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

## What this package is, and is not

PrismKit is the measurement layer: it collects what is on screen and, in debug
builds, reports it. It draws no conclusions.

Judging those measurements — auditing alignment, checking a screen against a
design, deciding what counts as an off-token spacing — happens in the tooling
that consumes them, not here. That tooling is closed source, which costs
nothing in trust: it never runs inside your app. This package does, which is
exactly why it is readable.

## Prism Inspector — the macOS companion

Measurements can stream to **[Prism Inspector](https://zalazara.github.io/PrismKit-SDK/)**, a free macOS app that inspects them without any overlay covering the simulator: a view tree, a Figma-style canvas with click-to-select and distance measuring, an inspector, saved sessions, and a design check that draws where each element should be against where it rendered.

The app bundles an MCP server, so an AI agent can read the same measurements and report what does not match a design — reading the node from whichever design tool it has connected, since the comparison takes a neutral description rather than talking to any one of them. The server and the comparison engine live with the app, not in this package: nothing here is macOS tooling, and everything here has to be readable by anyone deciding whether to embed it.

Streaming is on by default in `measureScope` and is a silent no-op when nothing is listening, so leaving it enabled costs nothing. PrismKit works fully without the app.

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
