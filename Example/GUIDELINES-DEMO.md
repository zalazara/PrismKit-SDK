# Guideline check demo — Apple's rules, on a running app

`DESIGN-DEMO.md` covers the app against **its own design**. This is the other
axis: the app against **Apple's published guidelines**, which needs no design
file and no instrumentation. Point Prism Inspector at any running app and the
rules apply.

Like the design demo, this app breaks them on purpose — and, more usefully,
breaks some of them by accident.

## What this proves

That the rules **measure the render rather than read the source**. Two of the
findings below are numbers you cannot get by looking at the code:

- A button written `.frame(width: 22, height: 22)` reaches the accessibility
  tree as **17 × 17**. The system decides what is tappable, not the modifier.
- Secondary text is `Shop.Palette.secondaryText`, which is `#8E8E93` — Apple's
  own systemGray. Against this app's `#F2F2F7` background it measures
  **2.8:1**, under the 4.5:1 Apple asks of body text.

The second one was never planted. It came with the palette, which is the point:
a real app inherits this from a design system that looks entirely reasonable.

## The rules

| Rule | What it asks | Where it reads it |
|---|---|---|
| Tap target | at least 44 × 44 pt for anything tappable | the accessibility frame — what the system hit-tests |
| Contrast | 4.5:1 for body text, 3:1 for large | the screenshot's pixels |

Contrast reports two verdicts, because the accessibility tree carries no font
size and inventing one would put a wrong number behind a real finding:

- **under 3:1** — short at any text size (red)
- **3:1 to 4.5:1** — fine if that text is large, not if it is body (amber)

## The manifest

Deep-link to each screen and open the warnings badge in the toolbar.

```sh
xcrun simctl launch <device> com.prismkit.example -autopush home
```

### home — 2 findings

| Element | Rule | Reported | Why |
|---|---|---|---|
| `home-search-clear` | Tap target | 15 × 15 pt | **Planted.** A clear button inside a 36 pt field cannot reach 44 — the classic real-world case |
| "Search products" | Contrast | 3.1:1 | The placeholder, in systemGray on white |

`10 checked and fine · 1 not judged`

### cart — 2 findings

| Element | Rule | Reported | Why |
|---|---|---|---|
| `cart-subtotal-info` | Tap target | 13 × 13 pt | **Planted.** Written as a 22 pt frame; the tree reports 13 |
| "Subtotal" | Contrast | 2.8:1 | systemGray on the `#F2F2F7` screen background |

`11 checked and fine`

### checkout — 4 findings

| Element | Rule | Reported |
|---|---|---|
| "Taxes calculated at checkout. 30-day returns." | Contrast | 2.8:1 |
| "Arrives Tue, Aug 4" | Contrast | 2.9:1 |
| "Shipping" | Contrast | 3.1:1 |
| "Subtotal" | Contrast | 3.1:1 |

`13 checked and fine`

None of these four were planted. They are what one palette choice costs across
one screen.

## What it deliberately will not tell you

The refusals matter as much as the findings, and each one is a case where
guessing would have been easy:

| Situation | What it does |
|---|---|
| A control clipped by a scroll view | Skips it. A half-visible row is not a small button |
| An icon inside a button | Skips it. The finger lands on the button; widening the glyph fixes nothing |
| A keyboard key | Skips it. The system keyboard is under 44 pt by Apple's own design |
| Text over a photo or gradient | Skips it. One ratio cannot describe a background that changes underneath |
| A row with a thumbnail beside its label | Skips it. The colour furthest from the background is the picture, not the text |

That last one is a real limit, not a subtlety: **a button whose label is merged
into one accessibility element is not contrast-checked.** The "Place order"
button here is never judged. Separating the text region inside a mixed element
is what would get it back. Until then, missing a finding beats inventing one.

Every screen reports what it skipped, so "no findings" and "nothing looked at"
can never be confused for each other.

## Fixing them, if you want to see the counts drop

- The two planted tap targets: give them a padded `contentShape` out to 44 × 44
  rather than growing the glyph.
- The contrast findings: `Shop.Palette.secondaryText` from `#8E8E93` to
  something near `#6D6D72`, which clears 4.5:1 on both backgrounds this app
  uses.

The design demo's seven findings are unaffected either way — the two demos
measure different things and neither moves the other's numbers.
