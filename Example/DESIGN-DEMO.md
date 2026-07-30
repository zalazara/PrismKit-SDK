# Design check demo — Pencil → PrismKit

This example app is built from `../Example.pen`, a six-frame Pencil document,
and it drifts from that design on purpose in seven places. Point an agent at
both and PrismKit reports those seven differences as numbers.

The point is not that a tool draws boxes. It is that **the design stops being a
picture someone glances at and becomes something a machine can hold you to.**

## What this actually proves

PrismKit does not talk to Pencil, or Figma, or anything else. It takes a
`DesignSpec` — a shape no design tool owns — and compares it against the live
accessibility tree of the running app. The agent is the bridge: it reads nodes
from whichever design MCP is connected and translates them.

So this demo proves two independent things:

1. An agent can turn a real design document into a `DesignSpec` without
   PrismKit knowing that Pencil exists.
2. The comparison catches genuine drift, and — just as important — it produces
   a false positive that a person has to recognise and silence. A tool that
   only ever agrees with you is not measuring anything.

## The pieces

| Piece | Where |
|---|---|
| The design (source of truth) | `../Example.pen`, six frames |
| The app built from it | `PrismKitExample/`, five screens |
| The defect manifest | this file, below |
| The comparison | PrismKit's MCP server, or Prism Inspector on the Mac |

The five screens are `screen-home`, `screen-product-detail`, `screen-cart`,
`screen-checkout` and `screen-confirmation`. The sixth frame, `foundations`,
is the design system: the spacing scale, the type ramp, the palette and the
radii, each labelled with its literal value so it can be read programmatically.

## Setup

The design frames are 393 × 852 pt, so run this on a device that is 393 pt
wide or the comparison scales and every number picks up sub-point noise:

```sh
xcrun simctl create "PrismKit Demo" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

Build and launch straight onto any screen — the flow is deep-linkable so the
guide is reproducible instead of "now tap here, then here":

```sh
xcrun simctl launch <udid> com.prismkit.example -autopush checkout
```

Slugs: `home`, `detail`, `cart`, `checkout`, `confirmation`, or any product
slug (`sneakers`, `camera`, …) to open that product's detail.

Streaming needs nothing else. `.measureScope()` wraps the `NavigationStack`,
so every pushed screen streams on its own.

### If the Pencil MCP server will not answer

Two failures cost real time while building this, both worth knowing:

- **The server needs `--agent`.** With `args: ["--app", "desktop"]` alone every
  call fails with `you are probably referencing the wrong .pen file`. The
  working configuration is `["--app", "desktop", "--agent", "claudeCodeCLI"]`.
- **The first call on a fresh connection times out** after ~62 s while the
  server registers the agent name, then dies. The immediate retry succeeds in
  under a second. Retry once before concluding anything is broken.

## The loop

### 1. Push the design system into PrismKit

Read `foundations` and hand PrismKit the same scale the design uses. Without
this step PrismKit judges spacing against its built-in guess at a design
system, and an "off-token" warning means nothing.

```
set_design_tokens(spacing_tokens: [4, 8, 12, 16, 20, 24, 32],
                  grid_size: 8,
                  project_path: "<repo>")
```

`project_path` writes a `.prismkit.json` that gets committed, so the server,
the Mac app and CI all judge spacing by the same numbers.

### 2. Translate a frame into a DesignSpec

`get_app_state` lists the top-level frames with their ids — `screen-checkout`
is `A7FHJt` in this document, and ids change if the file is rebuilt, so read
them rather than hard-coding them. Then one `execute` per frame returns a row
per node:

```js
f = Get("A7FHJt", {depth: 0})
FX = f.x
FY = f.y
Get("A7FHJt", (n, c) => {
  let x = 0, y = 0, k = c
  while (k) { x += k.bounds.x; y += k.bounds.y; k = k.parentCtx }
  Print([n.name,
         Math.round(x - FX), Math.round(y - FY),
         Math.round(c.bounds.width), Math.round(c.bounds.height),
         n.content === undefined ? "" : n.content].join(" | "))
})
```

`ctx.bounds` resolves in the parent's space, so the walk up `parentCtx`
accumulates an absolute position and subtracting the frame's own origin makes
it relative — which is what the comparator wants.

Set `match` to the name the app knows the view by. Here the Pencil layer
names and the `designNode(_:)` names are the same string on purpose, which is
what turns pairing from a guess into a fact.

```json
{
  "source": "pencil",
  "reference": "Example.pen#screen-checkout",
  "frame": { "width": 393, "height": 852 },
  "origin": "safeArea",
  "nodes": [
    { "id": "checkout-title", "match": "checkout-title",
      "frame": { "x": 16, "y": 24, "width": 361, "height": 28 },
      "text": "Review order" },
    { "id": "checkout-summary-title", "match": "checkout-summary-title",
      "frame": { "x": 16, "y": 352, "width": 154, "height": 22 },
      "text": "Payment summary" },
    { "id": "checkout-place-order-button", "match": "checkout-place-order-button",
      "frame": { "x": 16, "y": 553, "width": 361, "height": 52 } },
    { "id": "checkout-legal-caption", "match": "checkout-legal-caption",
      "frame": { "x": 16, "y": 617, "width": 361, "height": 16 },
      "text": "Taxes calculated at checkout. 30-day returns." }
  ]
}
```

`origin` is the field that decides whether this design describes one phone or
every phone. `"safeArea"` means the frame is measured from below the status
bar, notch or Dynamic Island, and PrismKit adds whatever inset the running
device reports — so `y: 24` is 83 on an iPhone 15 Pro and 44 on a device with
a 20 pt status bar, without the design being touched. Use `"screen"` only for
content that genuinely runs to the physical top: this demo uses it for the
product detail hero and the confirmation screen, and `"safeArea"` for the
other three.

A partial spec is fine and expected — describe the components that matter.

### 3. Attach, then compare

```
attach_design(design: <the spec>)
compare_to_design(tolerance: 6)
```

`tolerance: 6` is not arbitrary — it is just above the measured disagreement
between Pencil's text metrics and CoreText's, and well below the 8 pt defects.
See *Things that will bite you*.

`attach_design` also makes Prism Inspector draw the design over the live
screen: dashed where the design says it should be, solid where it rendered,
with the drift labelled. Anything the design specifies that is not on screen
appears as a dashed ghost in its intended place.

### 4. Fix and re-compare

Findings carry `matchedBy`. A finding matched by `identifier` is as certain as
the pairing; one matched by `overlap` was inferred geometrically and should be
checked before acting on it.

## The manifest

Seven defects, planted in the code only — the design is clean. Every one is a
distinct capability of the check. Verify a demo run against this table: a
finding that is not here, or a row here with no finding, is worth chasing.

Every defect is **8 pt**, and that is deliberate. Two text engines never agree
exactly: Pencil's glyph metrics run a little wider and taller than the
simulator's, so a comparison has a noise floor. Defects smaller than that floor
are indistinguishable from the floor. See *Things that will bite you*.

| # | Screen | Node | Design | App | Finding, as measured |
|---|---|---|---|---|---|
| 1 | home | `home-search` | height 44 | height 36 | `sizeMismatch` height −8 ✔ |
| 2 | detail | `detail-specs-card` | padding H 20 | padding H 12 | `positionMismatch` x −8 on all three labels, +9…+11 on the values, `sizeMismatch` width +16 on the rows ✔ |
| 3 | detail | `detail-shipping-note` | present at y 610 | absent | `missingElement` ✔ |
| 4 | cart | `cart-items-card` rows | gap 16 | gap 8 | `sizeMismatch` height −18 on the card, rows at −10.33 and −19 ✔ |
| 5 | checkout | `checkout-place-order-button` | height 52 | height 44 | `sizeMismatch` height −8 ✔ |
| 6 | checkout | `checkout-summary-title` | "Payment summary" | "Payment Summary" | `textMismatch` ✔ |
| 7 | confirmation | `confirmation-continue-button` | 32 below the card | 24 below | `positionMismatch` y −12.33 ✔ |

Run it yourself; a clean verification looks like this:

| Screen | Elements paired | By identifier | Findings |
|---|---|---|---|
| home | 47 | 47 | 47 |
| product detail | 17 | 17 | 15 |
| cart | 37 | 37 | 27 |
| checkout | 35 | 35 | 7 |
| confirmation | 16 | 16 | 2 |

**Every element pairs by identifier.** That is the whole reason for
`designNode(_:)`: not one pairing in the demo is a geometric guess, so not one
finding needs a second opinion before you act on it.

### Naming a view does not cost you its words

Defect #6 is worth understanding, because for a while it did not fire at all.
An instrumented measurement knows what a view is called; the accessibility
tree knows what it says. They were never joined, so
`DesignComparator.candidates(in:)` built instrumented candidates with
`text: nil` — and a node paired by identity could never fail on its copy. The
choice was exact pairing or copy checking, never both.

Candidates now borrow the words of the accessibility element occupying the
same frame, at a deliberately high overlap threshold so a card never adopts
the words of a label inside it. A view can also state its own copy through
`measure`'s metadata, which matters when the spoken label is not the visible
string — "427 dollars" read aloud for a label that shows "$427".

### The cascades are the lesson

Four of the seven move everything beneath them, and the report says so. This
is not noise to be tuned away — it is the honest shape of a layout bug:

| Root defect | Also reports |
|---|---|
| #1 search 8 pt short | the featured title, rail, popular title and list, and all their children — 45 further findings at Δy −9.67 to −14.67 |
| #2 card padding | six spec labels and values at Δx ∓8, and the three row widths at +16 |
| #4 cart gap | the sneakers row at −10.33, the lamp row at −19, the card height at −18, and the subtotal and button below |
| #5 button 8 pt short | `checkout-legal-caption` at Δy −14.67 |

One root cause, dozens of findings, one fix. A report listing only the root
cause would be hiding how much of the screen is actually wrong. It also
explains the finding counts above: home has 47 findings and one bug.

## The false positive

`checkout-delivery-estimate` is the case every real comparison hits. The design
states `Arrives Thu, Aug 6`, because a mock has to state something. The app
computes today + 5 days. Both are correct, and comparing them is meaningless —
exactly like a design that says `$0.00` against an app that correctly says
`$1,234.56`.

Both text findings on this screen are real reports of a real difference, and
exactly one of them is a defect:

```
textMismatch  checkout-summary-title      'Payment summary'    -> 'Payment Summary'
textMismatch  checkout-delivery-estimate  'Arrives Thu, Aug 6' -> 'Arrives Tue, Aug 4'
```

Telling them apart is a person's job, not the tool's. Once you have, the knob
is:

```
compare_to_design(compare_text: false)
```

which drops checkout from 7 findings to 5 — losing the capitalisation bug
along with the noise. That is the trade-off, stated plainly: text comparison
catches real copy drift and legitimate runtime differences with the same net.
Run it on, triage, then turn it off for the geometry pass.

## Things that will bite you

All of these cost real time while building this demo, and none of them are
specific to it:

**The simulator builds no accessibility tree until you ask it to.** Without the
OS-level flag, the snapshot arrives with the right screen size and zero
elements, and every design node reports `missingElement` — which reads exactly
like the app being broken. Set it once per simulator, then relaunch the app:

```sh
xcrun simctl spawn <udid> defaults write com.apple.Accessibility \
  ApplicationAccessibilityEnabled -bool true
xcrun simctl spawn <udid> defaults write com.apple.Accessibility \
  AccessibilityEnabled -bool true
```

Prism Inspector has a button for this in the inspector.

**`accessibilityIdentifier` does not reach the tree; `measure` does.** The
obvious way to name a view for pairing is `.accessibilityIdentifier`, and it
does not work: SwiftUI does not surface it to the runtime element PrismKit
reads, so `element.identifier` is nil and every node falls back to pairing by
copy or geometry. `.measure("name")` puts the name in the snapshot's
measurement groups, which is what the comparator's first pass matches on. The
`designNode(_:)` helper in `ShopTheme.swift` applies both — the identifier for
UI tests, the measurement for the design check.

**There is a noise floor, and it is bigger than you would guess.** Pencil and
CoreText do not lay out the same string identically. A 22 pt semibold title
measures 28 pt tall in the design and 26.33 pt on device; a long product name
is ~13 pt wider in Pencil than in the simulator. So:

- Structural geometry — cards, buttons, images, rows — compares cleanly.
- Leaf **text widths** are advisory. Treat a text node width within ~13 pt as
  agreement, not drift.
- Vertical cascades accumulate the per-line difference, which is why a single
  8 pt defect shows up downstream as −9.67 or −14.67 rather than a clean −8.
- Author text nodes in Pencil as `textGrowth: "auto"` when the app's label hugs
  its content. A `fixed-width` text box compared against a hugging SwiftUI
  `Text` produces width findings in the tens of points that mean nothing. All
  the hugging labels in `Example.pen` were switched to `auto` for this reason.

Run the comparison with `tolerance: 6`. It clears the metric noise and still
catches every 8 pt defect.

Three more, all about matching the design's assumptions to the device's:

**Say where the design frame is anchored.** The frames put the screen titles
at y 24, which on any modern iPhone is behind the Dynamic Island — because
that 24 is measured from the safe area, not from the glass. Declare that with
`origin: "safeArea"` and PrismKit resolves it against the device actually
running. Declare it wrong and every element lands at a constant offset.

Getting it wrong is worth seeing once. Re-run the checkout spec with
`"origin": "screen"` and the report does not become 35 findings — it becomes
one:

```
screenOffset  (whole screen)  +57.3
  All 35 matched elements sit +57.3 pt vertically from where the design puts
  them. Reported once instead of per element, and the differences below are
  measured with it removed. The design frame is anchored to the screen; if its
  content is drawn below the status bar, anchor it to the safe area instead
  (origin: "safeArea") and this resolves itself on every device.
```

The four real defects are still listed underneath, measured with the offset
removed. That collapse is deliberately hard to trigger: a layout bug high on a
screen also pushes everything below it, but by amounts that scatter, so it
stays reported per element. Only a genuinely rigid translation across most of
the screen is treated as one mistake.

**Compare against the design's language.** The design is in English. The
example ships a localisation catalogue, and on a Spanish simulator `Shop`
rendered as `Tienda` — four text mismatches that are correct behaviour. The
screens transcribed from the design now use `Text(verbatim:)` so they do not
localise. In a localised app you would instead relaunch in the design's
language, which Prism Inspector can do from the inspector.

**Match the device width.** The comparator derives its scale from the design
frame's width against the screen's. A 393 pt design on a 402 pt device is not
wrong, but every number gains sub-point error and the deltas stop reading
cleanly. Demo on the width you designed for.

## Extending this

The design and the app are meant to stay in step. If you change a screen in
`Example.pen`, rebuild the matching SwiftUI from it and leave the seven planted
defects alone — they are the demo's assertions. New defects are welcome; add
a row to the manifest with the finding it should produce, or it is not a
demonstration, just a bug.
