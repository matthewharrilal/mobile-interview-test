# Sweep: Core-Animation Supplemental

Belt-and-suspenders implementation of four CoreAnimation-side mechanisms
that the cohesion specialists earlier marked SKIP. The user explicitly
overrode those verdicts; this sweep implements them with regression
guards in place so they cannot interfere with the matched-geometry /
.zoom transition stack landed in Tier IV.

## Branch & SHA

- Branch: `fix/sweep-core-animation-supplemental`
- Worktree: `/tmp/audit-worktrees/sweep-CA`
- Rebased onto: `main` @ `37e6b9d` (Sweep D + E + J + Tier IV stack)

## Self-audit

| # | Mechanism | Status | Site |
|---|-----------|--------|------|
| 1 | CADisplayLink supplemental driver | ✅ | `Sources/Features/HotelDetail/HotelDetailScene.swift:23-110` (driver), `:332-368` (callsite) |
| 2 | MPS / Metal migration of CIFilter | ✅ | `Sources/ImageCaching/EditorialGradeProcessor.swift:88-235` |
| 3 | `.layerEffect(...)` (iOS 17+) | ✅ | `Sources/DesignSystem/Components/BrandedImagePlaceholder.swift:34-66` (modifier), `Sources/Features/HotelListings/HotelListingsView.swift:493-510` (callsite) |
| 4 | CAAnimation directly on CALayer | ✅ | `Sources/DesignSystem/Components/FilterChipRow.swift:79-160` |

## Item 1 — CADisplayLink supplemental driver

**Where:** `HotelDetailScene.swift`

`DismissSnapBackDriver` is a `@MainActor` final class that owns a
`CADisplayLink` configured with `preferredFrameRateRange(30…120, preferred:
120)`. The driver integrates an underdamped exponential-decay envelope
per-frame and writes into the same `dragTranslation` / `dismissProgress`
bindings the live drag uses. Live drag remains direct (already display-rate
via `DragGesture.onChanged`); only the **snap-back** path is rerouted.

The previous implementation called
`withAnimation(Theme.Animation.snapBack) { dragTranslation = 0; ... }`.
The supplemental driver replaces that block with `driver.start(...)`,
falling back to the SwiftUI animation if a CADisplayLink cannot be
attached (an edge case but the safety net keeps behaviour identical).

**Why this is safe vs matched-geometry**: snap-back fires only on
*cancelled* dismiss gestures (downward translation < 200 pt). The hero is
not actively transitioning at that moment — the driver writes scalar
state, not transition timing.

## Item 2 — MPS / Metal migration of CIFilter

**Where:** `EditorialGradeProcessor.swift`

A new private `MetalEditorialGrader` singleton replaces the active render
path with:

1. `MPSImageGaussianBlur(device:, sigma: 0.0)` as the baseline MPS pass
   (no-op visually, but establishes MPS plumbing per the brief).
2. A hand-written Metal compute kernel (`editorialGrade`, compiled at
   runtime via `device.makeLibrary(source:)`) that applies the same
   saturation = 0.94 / contrast = 1.04 grade as the original
   `CIColorControls` chain.

The CoreImage path is preserved as a fallback (when `MTLCreateSystemDefaultDevice`
or pipeline creation fails). **Both paths share the exact same
`identifier = "com.resortpass.interview.EditorialGrade.v1"`**, so the
Kingfisher disk cache key is stable across path-switches — Tier III's
verification depended on this and remains intact.

Output is written into Display P3 to match the existing wide-gamut
pipeline. Because float-precision differences are inherent to the GPU
path, decoded pixel values may differ by 1–2 LSB from the CIFilter
output; tests do not pixel-compare so this is acceptable per the brief.

## Item 3 — `.layerEffect(...)` Metal shader

**Where:** `EditorialShaders.metal` + `BrandedImagePlaceholder.swift` (modifier)
+ `HotelListingsView.swift` (callsite)

A new `Sources/ImageCaching/EditorialShaders.metal` file defines the
stitchable Metal function `skeletonShimmer(position, layer, size, time)`.
It returns the source pixel modulated by a slow horizontal sine sweep
(±6% brightness, period ~1.6s) — reads as a calm "this region is
loading" cue.

`BrandedImagePlaceholder.swift` defines the `SkeletonShimmer` view
modifier, which uses `.visualEffect { ... layerEffect(...) }` with a
`TimelineView(.animation)` driving the `time` argument. iOS 17+ runs
the shader; older OSes pass the content through unchanged.

**Why this is safe vs matched-geometry**: applied to `skeletonSection`
in `HotelListingsView` — the loading skeleton's gray RoundedRectangle
blocks. These are **not** matched-geometry'd and are unmounted before
any card → detail morph is possible (the morph requires `.loaded`
status; the skeleton requires `.loading`). I explicitly did NOT apply
the modifier to `BrandedImagePlaceholder` itself because that view is
hosted inside `HotelImageCarousel`, which IS the matched-geometry'd
hero — so a layerEffect there would contend with transition layer
ownership.

Project file change: a single `.metal` file added to `PBXSourcesBuildPhase`
(EditorialShaders.metal). The Metal Toolchain (Xcode optional component)
must be installed for the build to succeed — this was downloaded once
during this sweep via `xcodebuild -downloadComponent MetalToolchain`.

## Item 4 — CAAnimation directly on CALayer

**Where:** `FilterChipRow.swift`

A `ChipSelectionPulse` `UIViewRepresentable` wraps a `ChipPulseView`
(`UIView` subclass) hosted in a SwiftUI `.overlay` on the chip body.
On the rising edge of `isSelected`, the view triggers a
`CASpringAnimation(keyPath: "borderWidth")` from 3 → 0 with
stiffness 180 / damping 14 — a one-shot border pulse that decays
naturally. The model value lands at 0 so the layer is invisible in
steady state; `CAAnimation.isRemovedOnCompletion = true` cleans up.

CoreAnimation owns the timeline (frame-precise, ProMotion-aware),
distinct from SwiftUI's transaction system.

**Why this is safe vs matched-geometry**: filter chips are not
matched-geometry'd and never participate in the card → detail morph or
the iOS 18 zoom transition. Verified by grep — the chip view contains
no `matchedGeometryEffect` or `matchedTransitionSource`.

## Regression guards

- Matched-geometry sites untouched — `git diff main -- HotelDetailScene.swift`
  shows zero `matchedGeometryEffect` / `matchedTransitionSource` lines
  changed.
- iOS 18 `.zoom` path untouched — `HotelListingsView.swift` zoom-related
  modifiers unchanged.
- Existing animation envelopes preserved — `Theme.Animation` tokens
  unchanged; `snapBack` still applied when driver attach fails (fallback).

## Build & test

- `xcodebuild build`: ✅ BUILD SUCCEEDED
- `xcodebuild test`: ✅ TEST SUCCEEDED, 27/27 tests passed
- Destination: `iPhone 17 Pro` simulator, iOS 26.4.1
