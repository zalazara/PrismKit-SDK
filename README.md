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

`measure` also records where it was written, so a finding can point at the line
of code instead of at a name to go and search for. If you wrap it in a helper —
which is the normal thing to do — the helper has to declare and forward the
location, or every view it wraps reports the helper's own line:

```swift
func designNode(
    _ name: String,
    file: String = #fileID,
    line: Int = #line
) -> some View {
    accessibilityIdentifier(name).measure(name, file: file, line: line)
}
```

### Values you let the tooling change

Size can be overridden from outside, because `measure` wraps the view and can
impose a frame on it. Padding, colour and copy cannot: they are arguments a
component was built with, and from outside the process there is no object left
to ask. So the component offers them, by handing over the binding it already
owns:

```swift
@State private var cardPadding: CGFloat = 16

VStack { … }
    .padding(cardPadding)
    .measureTweak("Card padding", $cardPadding, in: 0...48)
```

`CGFloat`, `Bool` and `String`. Give bounds when the value has them and the
companion shows a slider; leave them off and it shows a field, because a slider
with invented limits states a range nobody chose. Changing one goes through
your own state, so the app re-lays-out for real — text rewraps and everything
below it moves.

### Pictures of a component leave the process

The companion can ask the app to draw a component on its own, which is how it
tells a covered element from an invisible one. If some of your views should not
travel — anything showing a card number or a medical record — say so:

```swift
PrismKit.rendersComponent = { id in !id.hasPrefix("payment-") }
```

Refusing one does not hide it: its geometry is still measured and reported.
This governs the picture only.

### Configuration

```swift
.measureScope(configuration: MeasureConfiguration(
    gridSize: 8,
    spacingTokens: [4, 8, 12, 16, 24, 32, 40, 48],
    showsGrid: true
))
```

Padding and spacing are checked against `spacingTokens`: valid values render green, invalid ones red with the nearest token, e.g. `13→12`.

The overlay layers start off. Drawing bounds, sizes and padding for every
instrumented view at once is legible on a demo screen and unreadable on a real
one, so a screen comes up clean and you turn on what you need — from the
floating toolbar, or by passing the flags above.

On a busy screen the better route is the select button beside the toolbar's
ruler: arm it, tap a component and only that one is drawn; tap a second and you
get the distance between them.

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

It works on a real device too, not only in the simulator. On a phone the app
listens and the Mac reaches in over the cable through `usbmuxd` — the same
mechanism Xcode has always used — so an attached device appears in the
companion's device menu beside your booted simulators. Nothing to configure at
this end: plug the phone in, run your app, pick it.

## Example app

`Example/PrismKitExample.xcodeproj` is a runnable, instrumented sample:

```
open Example/PrismKitExample.xcodeproj
```

## Limitations

- **SwiftUI only.** No UIKit support in this version.
- **Element discovery comes from the accessibility tree.** That covers most meaningful UI, but not purely decorative views, and it needs the accessibility flag described above. Internal padding and semantic grouping still need the optional `measure(_:role:)` calls, because SwiftUI exposes no public runtime view graph to infer them from.
- **Not a general-purpose debugger.** For runtime property inspection use Lookin, Reveal, or the Xcode view debugger.
- **Drawing a component on its own needs iOS 16.** Below that there is no way to rasterise a SwiftUI view off screen without rearranging the live hierarchy, which would make the app being measured flicker. Everything else works on iOS 15.
- Overlay labels for measurements scrolled offscreen can draw outside the visible viewport.

## License

[MIT](LICENSE). Embed it in your app, commercial or not.
