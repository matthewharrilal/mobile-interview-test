# Sweep E — Sub-Pixel Stability Audit

**Branch:** `fix/sweep-E-subpixel`
**Base:** `main` @ `f521c58`
**Scope:** every site in `Sources/` that could produce sub-pixel wobble during interpolation, animation, or scroll.

## Method

Grepped `Sources/` for every fractional literal (`0\.[0-9]+`), every `.frame(`, `.padding(`, `.offset(`, `lineWidth:`, every `ScaledMetric`, and every `Theme.Spacing.*` arithmetic. Read each site, classified as *fix-required* (sub-pixel-risk that visibly wobbles) vs *intentional / not-a-risk* with explicit rationale.

Sites visited: **22 distinct fractional or interpolating-frame call sites** across 9 files. Fixes applied: **3** (all hairline strokes/rules). Sites left as-is with rationale: **9** (ScaledMetrics, scroll-driven parallax, drag-driven rubber-band, integer destination frames, scale-feedback animations, opacity/blur-radius scalars).

---

## Fixes applied (3)

### 1. `Theme.Spacing.hairline` constant — added

**File:** `Sources/DesignSystem/Tokens/Theme.swift:36-52`
**Change:** added `static let hairline: CGFloat = 1.0 / UIScreen.main.scale` (and `import UIKit`).

```swift
/// Single physical-pixel hairline (1.0 / device scale). On @2x =
/// 0.5 pt, on @3x ≈ 0.333 pt — both land exactly on the device
/// pixel grid so a stroke or frame at this thickness renders as
/// one crisp pixel without anti-aliased blur.
static let hairline: CGFloat = 1.0 / UIScreen.main.scale
```

**Rationale:** `0.5` pt is a *one-physical-pixel* hairline only on @2x devices. On @3x (iPhone 17 Pro), 0.5 pt = 1.5 physical pixels → the renderer anti-aliases across two rows, producing a visibly soft 1.5-px blur. `1.0 / UIScreen.main.scale` lands exactly on the pixel grid for the actual device — the standard scale-aware hairline pattern.

### 2. Section header rule — `HotelListingsView.swift:414`

**Before:** `.frame(height: 0.5)`
**After:**  `.frame(height: Theme.Spacing.hairline)`

The decorative editorial rule next to `section.title`. Rendered on every section header.

### 3. Filter chip outline — `FilterChipRow.swift:61`

**Before:** `Capsule().stroke(..., lineWidth: 0.5)`
**After:**  `Capsule().stroke(..., lineWidth: Theme.Spacing.hairline)`

Outline visible on every unselected filter chip (4–6 chips in the row, always on screen during browsing). Fix is more visible than the section rule because there are more of them.

### 4. Hotel-star badge outline — `HotelImageCarousel.swift:98`

**Before:** `Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.5)`
**After:**  `Capsule().stroke(Color.white.opacity(0.35), lineWidth: Theme.Spacing.hairline)`

White hairline around the floating "5★" capsule that overlays every hotel image. This stroke morphs *with the hero* during the card→detail transition — it was the highest-leverage hairline because it interpolates during the 250 ms morph. Fix is most visible during morph.

---

## Sites checked, left as-is, with rationale (9)

### `@ScaledMetric` source frames — *intentional, static per Dynamic Type setting*

| File | Line | Value |
|---|---|---|
| `CompactHotelCard.swift` | 17 | `cardWidth: CGFloat = 220` |
| `CompactHotelCard.swift` | 18 | `cardImageHeight: CGFloat = 200` |
| `HotelListingsView.swift` | 47 | `heroHeight: CGFloat = 360` |

At default Dynamic Type, all three resolve to integer pt values (`220.0`, `200.0`, `360.0`). At `xxLarge` and accessibility sizes, Apple's accessibility multipliers produce fractional pt — but these values are **static for a given Dynamic Type setting**; they do not interpolate during animation. The morph spring crosses sub-pixel values mid-flight regardless (spring interpolating 200→360 passes through 234.7 etc.), and that is mitigated at the rendering-pipeline layer by `compositingGroup()` (already in place from Tier-Cohesion-II — `HotelDetailScene.swift:155`). Rounding `@ScaledMetric` to integer pt at the source would defeat continuous accessibility scaling without removing the mid-flight sub-pixel rendering.

### Parallax stretch — *intentional, scroll-driven smooth motion*

| File | Line | Value |
|---|---|---|
| `HotelListingsView.swift` | 324 | `frame(width: ..., height: heroHeight + stretch)` |
| `HotelListingsView.swift` | 325 | `.offset(y: -stretch / 2 - parallax)` |
| `HotelListingsView.swift` | 326 | `.scaleEffect(1.0 + (stretch / 2400.0))` |

`stretch` and `parallax` are scroll-pull values (`max(0, offset)` / `max(0, -offset / 3)`). They produce continuously fractional frame heights, offsets, and scales — but this is **scroll-driven**, not spring-driven. The 120 Hz display-link delivers a fresh `offset` on every frame; the rendered surface advances by sub-pixel increments per frame, which is what makes ProMotion scroll feel buttery. Quantizing to integer pt would introduce visible 1-pt-step jitter on every frame at slow scroll speeds — strictly worse than the sub-pixel rendering. Not a "wobble" candidate.

### Rubber-band drag offset — *intentional, gesture-driven smooth motion*

| File | Line | Value |
|---|---|---|
| `HotelDetailScene.swift` | 241 | `.offset(y: rubberBandedOffset(...))` (sqrt-damped) |

`rubberBandedOffset` returns `dismissCancelBelow + sqrt(excess * 40)` past 100 pt — fractional by design. Same rationale as parallax: gesture-driven, not spring-driven. The user's finger position updates each frame; sub-pixel rendering gives the perceptual fidelity. Quantizing would produce visible 1-pt step jitter as the finger moves.

### Integer destination frames — *integer, mid-flight sub-pixel handled by `compositingGroup`*

| File | Line | Value |
|---|---|---|
| `HotelDetailScene.swift` | 227, 238, 257 | `frame(height: 360)` |
| `HotelListingsView.swift` | 388 | `frame(height: heroHeight)` |

Source (`200`) and destination (`360`) frame heights are integer pt. The morph spring's mid-flight interpolation crosses sub-pixel values for 250 ms — that's intrinsic to spring animation and not fixable at the call site. Mitigation is at the rendering-pipeline level (`compositingGroup()` already on the matched-geometry ZStack — keeps the layer-promoted backing store stable so the GPU doesn't re-rasterize the soft-edge content per frame).

### Press-feedback and peek scales — *intentional, brief, tap-only or already suppressed during morph*

| File | Line | Value |
|---|---|---|
| `CardPressStyle.swift` | 10 | `.scaleEffect(0.97)` |
| `HotelListingsView.swift` | 452 | `.scaleEffect(0.94)` (peek edge) |

The 0.97 press scale lasts ~0.20 s and serves as immediate tap feedback — quantizing would produce a visible "click" snap on press. The 0.94 peek scale is already gated by `suppress = viewModel.state.presentation != .browsing`, so it is **inactive during morph**; only active during scroll where smooth fractional scaling is desired.

### Shadow blur radius — *not a layout/positioning concern*

| File | Line | Value |
|---|---|---|
| `CompactHotelCard.swift` | 39 | `radius: Theme.Elevation.cardCast.radius * 0.6` |

Fractional Gaussian blur radius. Doesn't produce wobble — it's a filter parameter, not a position. A blur radius of 10.8 vs 11.0 differs by an imperceptible 0.2-px-wide softness band.

### Opacity / blur scalars — *not a layout concern*

| File | Line | Value |
|---|---|---|
| `HotelListingsView.swift` | 166 | `(1 - progress) * 24` (blur radius) |
| `HotelListingsView.swift` | 179 | `0.7 + (1.0 - 0.7) * Double(progress)` (opacity) |

Both are continuous filter scalars — opacity and blur radius. Neither affects geometry. Fractional interpolation is required for smooth fade + blur ramps.

### `Theme.Spacing.*` arithmetic — *all integer-valued*

All `Theme.Spacing.s + 1`, `Theme.Spacing.s + 2`, `Theme.Spacing.m + 2` etc. across `FilterChipRow`, `SearchView`, `HotelListingsView` resolve to integer pt (8 + 1 = 9, 8 + 2 = 10, 16 + 2 = 18). No sub-pixel risk introduced by the arithmetic.

### Velocity / opacity literals — *not layout values*

| File | Line | Value |
|---|---|---|
| `HotelDetailScene.swift` | 226 | `Color.black.opacity(0.001)` (carrier-rectangle invisibility) |
| `HotelDetailScene.swift` | 229 | `.shadow(color: .black.opacity(0.18), radius: 24, y: 12)` |
| `HotelDetailScene.swift` | 292 | `(predicted - downward) / 0.1` (velocity calc) |
| `StarRating.swift` | 29 | `value >= position + 0.5` (half-star comparison) |

Color opacities, shadow opacities, velocity divisors, and value comparisons. None of these are pt values that affect frame geometry.

### `padding(.horizontal, 4)` etc. — *integer*

`CompactHotelCard.swift:84`, `HotelImageCarousel.swift:96, 106`, `SearchView.swift:168` — all integer pt.

---

## Why this audit is broader than the Tier II shadow-only fix

Tier II's `compositingGroup()` addressed *one* class of sub-pixel wobble: shadow re-rasterization mid-morph. This audit checks every other class:

- **Hairline borders** — Tier II didn't touch these. Three were on the wrong side of the pixel grid on @3x. Now scale-aware.
- **Interpolating frames** — confirmed no fractional integer destinations and that mid-flight sub-pixel is already handled by `compositingGroup`.
- **ScaledMetric** — confirmed values are integer at default Dynamic Type and intentional at accessibility sizes.
- **Drag and parallax offsets** — confirmed these are gesture/scroll-driven (correct to be sub-pixel) not spring-driven (would-wobble).
- **Theme.Spacing arithmetic** — confirmed all expressions resolve to integer pt.

## Verification

- **Build:** `BUILD SUCCEEDED` for `iPhone 17 Pro / iOS 26.4.1`
- **Tests:** `27 / 27 passed` (`** TEST SUCCEEDED **`)

## Files modified

- `Sources/DesignSystem/Tokens/Theme.swift` — `import UIKit` + `Theme.Spacing.hairline`
- `Sources/Features/HotelListings/HotelListingsView.swift` — section-header hairline
- `Sources/DesignSystem/Components/FilterChipRow.swift` — chip outline hairline
- `Sources/DesignSystem/Components/HotelImageCarousel.swift` — star-badge hairline
