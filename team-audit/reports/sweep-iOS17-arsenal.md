# Sweep iOS17 Arsenal — Three iOS 17+ Mechanisms

**Branch:** `fix/sweep-iOS17-arsenal`
**Base:** `main` @ `37e6b9d`
**Build:** `** BUILD SUCCEEDED **`
**Tests:** `27/27 passed` (0 failures, 9.0s)

---

## Problem Recap

User's Image 12–15 critique flagged: when the detail materialises after the
morph, every text element appears AT FINAL POSITION simultaneously. The
Airbnb reference shows staggered arrival, per-property timing variation,
and digit-rolling on the price. None of these were present in HotelDetailScene
before this sweep.

---

## Self-Audit

| # | Mechanism | Status | File:line |
|---|---|---|---|
| 1 | PhaseAnimator on staggered destination arrival | ✅ | `HotelDetailScene.swift:404` (StaggerArrival modifier) + applied at lines 326, 351, 374, 386 |
| 2 | KeyframeAnimator on per-property timing | ✅ | `HotelDetailScene.swift:430` (KeyframeArrival modifier) + applied at line 339 (title) |
| 3 | `.contentTransition(.numericText)` on price | ✅ | `HotelDetailScene.swift:399` (detail price) + `CompactHotelCard.swift:84` (listings price) |

---

## Mechanism 1 — PhaseAnimator (Staggered Arrival)

**Where:** `Sources/Features/HotelDetail/HotelDetailScene.swift`
- Modifier definition: lines 404–423 (`StaggerArrival`)
- Applied to: location eyebrow (line 326), rating (line 351), product info VStack
  (line 374), price block (line 386)

**Trigger:** `contentArrivalTrigger: Bool` @State (line 65), flipped `true`
in both `overlayBody.onAppear` (line 178) and `pushedBody.onAppear` (line 199).

**Phase contract:**
- `phase = 0.0` → `opacity = 0`, `offset.y = +12pt` (initial)
- `phase = 1.0` → `opacity = 1`, `offset.y = 0` (visible)

**Cadence (5 stagger slots):**
| index | element | delay (s) |
|---|---|---|
| 0 | location eyebrow | 0.16 |
| 1 | hotel name (KeyframeAnimator) | 0.23 |
| 2 | rating row | 0.30 |
| 3 | product info (VStack) | 0.37 |
| 4 | price block | 0.44 |

Total spread: 0.16 → 0.44 = **0.28s** (matches the 280ms target). Lead-in
of 0.16s aligns with the morph spring's geometry settle (~150ms) plus a
~10ms beat.

**Tokens added** (`Theme.swift:182–207`):
- `Theme.Animation.contentArrival` — `spring(response: 0.32, dampingFraction: 0.85)`,
  intentionally under-damped so each line has perceptible physical weight
- `Theme.Animation.contentArrivalLeadIn = 0.16`
- `Theme.Animation.contentArrivalStaggerStep = 0.07`

**Rationale for using PhaseAnimator (not raw `.animation(value:)`):** the
two-phase `[0.0, 1.0]` model with a single trigger keeps state mutation
deterministic — re-tap forces fresh identity (`.id(sourceID)` on the
overlay scene), so PhaseAnimator replays cleanly. A scattering of
per-element @State bools would require N separate `withAnimation` blocks
and would race on rapid re-taps.

---

## Mechanism 2 — KeyframeAnimator (Per-Property Timing)

**Where:** `Sources/Features/HotelDetail/HotelDetailScene.swift:430–467`
(`KeyframeArrival` modifier), applied to the hotel name at line 339.

**Why the title specifically:** the title is the heaviest piece of
typography on the surface (28pt Playfair display semibold). When it
arrives, the asymmetric position-vs-opacity timing produces the
"weight distribution" feeling the user's Image 12 critique called for.
A single Animation curve cannot produce this effect.

**Track 1 — Position (`offsetY`):**
```swift
KeyframeTrack(\.offsetY) {
    LinearKeyframe(12, duration: leadIn)         // hold at +12 during lead-in
    SpringKeyframe(0, duration: 0.45, spring: .smooth(duration: 0.45, extraBounce: 0.18))
}
```
0.45s spring with a light extraBounce of 0.18 — the title settles slowly
with subtle physical weight, not snappy.

**Track 2 — Opacity:**
```swift
KeyframeTrack(\.opacity) {
    LinearKeyframe(0, duration: leadIn)          // hold invisible during lead-in
    CubicKeyframe(1.0, duration: 0.20)
}
```
0.20s cubic ease — significantly faster than the 0.45s position spring.
The title becomes legible BEFORE its position fully resolves; this
asymmetry IS the perceptual weight.

**Lead-in mechanism:** KeyframeAnimator does not natively support an
up-front delay, so the leading `LinearKeyframe(initial, duration: leadIn)`
in each track holds at the initial value. Same effect, declarative.

**Trigger:** the same `contentArrivalTrigger` flag drives this — the
keyframe sequence plays once when the trigger flips false → true.

---

## Mechanism 3 — `.contentTransition(.numericText)` on Price

**Where:**
1. `Sources/Features/HotelDetail/HotelDetailScene.swift:399` — detail's
   price label (`Text("\(currency.symbol)\(Int(price))")`)
2. `Sources/DesignSystem/Components/CompactHotelCard.swift:84` —
   listings card's price label (same composition)

**Why both sites:** matched-geometry / `.zoom` morphs the card's price
into the detail's price. If only one wears `.contentTransition(.numericText)`,
a currency switch would crossfade on one and digit-roll on the other —
incoherent. Wiring both keeps the morph reading as a single unbroken
typographic transition.

**API choice:** `.contentTransition(.numericText())` (no arguments).
This is iOS 17+. The deployment target is iOS 17.0 so no `#available`
guard is needed.

**Future trigger:** there is no currency-toggle UI yet, so the digit-roll
will primarily fire on data refresh (pull-to-refresh, retry). The wiring
is in place for any future currency picker.

---

## Regression Guards

✅ `.matchedGeometryEffect` and `.matchedTransitionSource` not touched —
they remain on the hero (`overlayHero`) and the carousel cards
(`MatchedSourceIfAvailable` modifier).

✅ iOS 18 `.zoom` path verified: `pushedBody` does NOT animate text
arrival — it only morphs the hero's geometry. PhaseAnimator does not
double-stagger because zoom's destination snapshot is opaque to
SwiftUI's per-element animations; staggered arrival begins after
mount, in the destination view's own render tree.

✅ Drag-to-dismiss (`dismissDrag`): PhaseAnimator and KeyframeAnimator
run once on appear and don't reverse. Dismiss is driven by the host's
morph spring on the hero geometry; the staggered text content fades
out as part of the surface unmount transition (no PhaseAnimator
involvement). No reverse-stagger risk.

✅ Re-tap re-mount: `.id(sourceID)` on `HotelDetailScene` (HotelListingsView.swift:131)
forces fresh identity per tap → `contentArrivalTrigger` resets to false →
`.onAppear` re-flips → cadence replays fresh. Verified by reading the
host code path.

✅ `contentOpacity` semantics preserved: still drives the surface
background, shadow carrier, and close button. Only its application
to the inner `content` block was lifted (the per-element stagger
now owns content visibility).

---

## Token Inventory (additions)

`Sources/DesignSystem/Tokens/Theme.swift:182–207`:
- `contentArrival` — Animation
- `contentArrivalLeadIn` — Double (0.16)
- `contentArrivalStaggerStep` — Double (0.07)

No existing tokens were renamed or repurposed.

---

## Verification

```
$ xcodebuild ... build
** BUILD SUCCEEDED **

$ xcodebuild ... test
Test Suite 'All tests' passed at 2026-05-10 11:10:59.483.
Executed 27 tests, with 0 failures (0 unexpected) in 9.008 (9.029) seconds
** TEST SUCCEEDED **
```
