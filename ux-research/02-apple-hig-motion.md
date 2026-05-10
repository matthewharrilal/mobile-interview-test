# Apple HIG: Motion, Animation, Micro-Interactions

**Audience:** ResortPass iOS engineers building hotel-card / search-row UX in SwiftUI on iOS 17+.
**Goal:** Translate Apple's stated guidance and the platform's default motion vocabulary into concrete, opinionated rules for the hotel browse / search surface, so the app feels native rather than novel.

This brief is intentionally narrow. It is not a survey of motion design — it is the constitution we will animate against. Every recipe at the bottom should compile and ship.

---

## 1. Apple's animation principles (HIG: Foundations > Motion)

Apple's HIG opens its Motion section with: *"Beautiful, fluid motions bring the interface to life, conveying status, providing feedback and instruction, and enriching the visual experience of your app or game."* The four stated principles, paraphrased from the Motion page, are:

1. **Use motion to communicate.** Motion exists to *show* what changed, what will happen if the user acts, and what is now possible. If an animation does not answer one of those three questions, it is decoration and should be cut. For a hotel row this means: the press state communicates "you hit the right target," the row insertion communicates "this result is new," and the detail-push communicates "you are now one level deeper."
2. **Add motion purposefully.** Animations should keep the user oriented and avoid overwhelming them. Translation for our search results list: animate the *first* render of the result set; do not animate every keystroke-driven re-sort.
3. **Avoid excessive motion.** Apple is explicit: *"avoid adding motion to interactions that occur frequently. The system already provides subtle animations for interactions with standard interface elements."* This is the rule that should bias us toward `List`, `NavigationStack`, and stock `Button` over hand-rolled equivalents — we get the right motion for free.
4. **Make motion optional.** Anything load-bearing must be communicated by something other than motion (label change, icon change, color, haptic). Motion is an enhancement layer, never the only signal.

A useful mental model: **the system's defaults are the ceiling, not the floor.** Custom motion has to clear a higher bar than "looks nice in the prototype" — it has to outperform what UIKit/SwiftUI would have done on its own.

> Source: developer.apple.com/design/human-interface-guidelines/motion

---

## 2. Standard system durations and curves

Knowing what the platform reaches for under the hood lets us match it without guessing.

**SwiftUI presets (iOS 17+):**

| Preset | Use it for | Notes |
|---|---|---|
| `.smooth` | Default for `withAnimation { … }` in iOS 17+. No bounce. | Equivalent to `withAnimation(.smooth)`. The "non-bouncy spring" Apple uses for sheets, app launch, and `NavigationLink` push/pop. |
| `.snappy` | Quick state flips, toggles, segmented control changes. Small bounce. | Closest to UIKit's classic "ease-in-out @ ~0.25s" feel without committing to a fixed duration. |
| `.bouncy` | User-initiated, "physical" gestures (pull-to-refresh release, drag-and-drop snap-back). Larger bounce. | Reserve for rare, celebratory moments. Overuse cheapens it. |

**Legacy spring defaults still in play:**

- `Animation.spring()` (no args) → `response: 0.55`, `dampingFraction: 0.825`, `blendDuration: 0`.
- `Animation.interactiveSpring()` → `response: 0.15`, `dampingFraction: 0.86`, `blendDuration: 0.25`. Built for follow-the-finger gestures; use it when the animation is responding to active touch.

**UIKit baselines (still informative because SwiftUI matches them):**

- `UIView.animate(withDuration:)` historical default: **0.25s, ease-in-out**. This is the duration to use for any duration-based fallback.
- `UINavigationController` push/pop: **~0.35s** with a system curve (slide-in from trailing edge, parallax on the popped view).
- `UIView` cross-dissolve: **0.25s** ease-in-out.

**Engineering rule:** prefer SwiftUI's named presets (`.smooth`, `.snappy`, `.bouncy`) over hand-tuned springs. They will track Apple's evolving "system feel" automatically across OS versions. Only drop down to `.spring(response:dampingFraction:)` if you have a measured reason.

> Sources: developer.apple.com/documentation/swiftui/animation, WWDC23 "Explore SwiftUI animation."

---

## 3. Tap feedback (press states)

Apple's Buttons HIG: every button must have a clearly distinguishable pressed state. Stock `UIButton` and SwiftUI `Button` already do this — when pressed they reduce opacity to roughly **0.3** (UIKit `adjustsImageWhenHighlighted` / SwiftUI's automatic style), and on release fade back to opaque using a short ease-out.

For our hotel row, which is effectively a tappable card, the engineering call is:

1. **Use `Button` (or wrap the row in a `NavigationLink`), not a `TapGesture` on a `VStack`.** Gestures don't get the system pressed-state visual, don't get proper accessibility traits, and don't get the haptic-friendly hit-test behavior.
2. **Wrap in a custom `ButtonStyle`** that defines the press state explicitly. For card UI, the iOS-native press feel is a combination of:
   - Slight scale-down: `scaleEffect(configuration.isPressed ? 0.97 : 1.0)`
   - Slight opacity dip: `.opacity(configuration.isPressed ? 0.85 : 1.0)`
   - `.animation(.snappy(duration: 0.2), value: configuration.isPressed)` so press-in is instant-feeling and release decays naturally.
3. **Press-in should feel synchronous (≤ 50ms perceived).** Press-out can be slower (~200ms). Asymmetric timing matches how the system stock buttons behave and is what makes a tap feel "alive."

Anti-pattern: animating the press-in over 300ms+. The user will release the finger before the visual catches up and it will feel laggy. The default SwiftUI `.borderless`/`.bordered` button styles get this right — match them.

> Source: developer.apple.com/design/human-interface-guidelines/buttons

---

## 4. List + cell animation

`List` and `LazyVStack` already animate insertions, deletions, and moves correctly when their data source changes inside `withAnimation`. The HIG-aligned defaults:

- **Cell selection:** `List` row tap fades the selection background in over ~0.2s and out on navigation push. Don't add your own flash.
- **Row insertion / deletion:** wrapping the data mutation in `withAnimation` gives a slide+fade per row. With identifiable data (`Identifiable` conformance, stable IDs), SwiftUI diffs and animates only the changed rows. **Stable IDs are not optional** — without them you will get an entire-list re-render and the animation will look like a flash.
- **Swipe actions (`.swipeActions`):** the reveal animation is system-handled, follows the finger, and snaps with a non-bouncy spring on release. Do not wrap `.swipeActions` content in your own animation; it will fight the system.
- **`.listRowInsertion` / `.listRowSeparator` / `.listRowBackground`:** apply these as static modifiers. Animating them per-row is almost always a mistake — the row's own insertion animation already covers the visual change.

For the search results list specifically:

- When the result set changes due to a debounced query, animate with `.smooth` (or no animation at all on rapid keystrokes — see §5).
- When a single row updates (e.g., availability badge changes from "Available" to "Sold Out"), animate *the changed sub-view*, not the row container, with `.snappy`.

> Sources: developer.apple.com/documentation/swiftui/view/swipeactions, developer.apple.com/documentation/uikit/uitableview/rowanimation

---

## 5. Reduce Motion

This is non-negotiable. From the HIG: *"When the Reduce Motion accessibility setting is on, be sure to minimize or eliminate animations. Additionally, certain types of motion, such as scaling, spinning, or peripheral motion, cause dizziness or nausea for people with motion sensitivity."*

**Engineering rules:**

1. Read the user's preference once at the view level:
   ```swift
   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   ```
2. **Never disable animation entirely as the substitute** — Apple's guidance is to *replace* movement-based animations with cross-fades, not to skip the transition. A cross-fade still communicates "something changed."
3. The classes of motion that *must* have a Reduce Motion alternative:
   - **Scale and zoom** (e.g., card press scale-down, hero image zoom-in on tap).
   - **Parallax and peripheral motion** (e.g., image inside card moving at a different rate than the card).
   - **Spring overshoot / bounce** (anything `.bouncy`).
   - **Spinning indicators with translation** (avoid; `ProgressView()` is fine — it's in-place rotation).
4. **Acceptable replacements:** `.opacity` cross-fades over ~0.2s, instant state changes with no animation, or a very short `.linear(duration: 0.15)`.

**Pattern for the hotel row press state:**

```swift
.scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
.opacity(configuration.isPressed ? 0.85 : 1.0) // opacity is safe under Reduce Motion
```

**How to test in the simulator:**

- Settings → Accessibility → Motion → Reduce Motion → ON.
- Or, in Simulator menu: **Features → Toggle Appearance** has accessibility toggles in newer Xcode versions; otherwise drive it via Settings.app inside the sim.
- Set up an Xcode scheme arg `-UIAccessibilityReduceMotionEnabled YES` for fast launch-time toggling during dev.
- Add an `accessibilityReduceMotion` snapshot test variant for any screen that has non-trivial motion.

> Sources: developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion, HIG Motion page (Reduce Motion section).

---

## 6. Haptic feedback

There are two APIs and a clear decision rule.

**APIs:**

- **`UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` / `UISelectionFeedbackGenerator`** (UIKit, iOS 10+). Imperative. Requires `prepare()` to minimize latency.
- **`.sensoryFeedback(_:trigger:)`** (SwiftUI, iOS 17+). Declarative. Fires when the trigger value changes. Wraps the same Taptic Engine APIs.

**Rule:** in a SwiftUI view, use `.sensoryFeedback`. It's less code, harder to misuse, and binds the haptic to a state change so it can't fire twice or fail to fire on a re-render. Drop to UIKit only when you need imperative timing (e.g., sequenced haptics tied to a game loop or animation curve).

**When to use which feedback type — short version:**

| Type | Use for | Hotel app example |
|---|---|---|
| `.selection` | Picking from a series (segmented control, picker scroll, filter chip). Subtle. | Switching between "Day Pass" / "Cabana" tabs. |
| `.impact(.light)` | Confirming a small, frequent action. UI element snaps into place. | Toggling a heart/favorite on a hotel card. |
| `.impact(.medium)` | A distinct, intentional action. Default for "I did a thing." | Hotel card tap that pushes detail. |
| `.impact(.heavy)` | Significant, infrequent action with weight. | Confirming a booking. |
| `.success` | Operation completed successfully and the user should know. | Booking confirmed. |
| `.warning` | Operation completed but with caveats; needs user attention. | Booking saved offline; will sync later. |
| `.error` | Operation failed in a way the user must acknowledge. | Booking declined / payment failed. |
| `.increase` / `.decrease` | Continuous numeric adjustments. | Guest-count stepper. |

**Apple's stated constraints:**

- Use haptics consistently throughout the app. Same action → same haptic, every time.
- Pair every haptic with a visible UI change. *"The source of the feedback must be clear to the user."* A haptic with no visual = a phantom buzz.
- Don't pick a haptic because it feels good. Pick the one that matches what happened.
- Don't overuse. Every-tap haptics are exhausting and dilute the meaningful ones.

**For the hotel row specifically:** `.sensoryFeedback(.impact(.light), trigger: tapCount)` on the favorite toggle. **No haptic on the row tap itself** — `NavigationLink` push is frequent and the visual transition is feedback enough. Reserve `.medium` impact for the booking CTA on the detail screen.

> Sources: developer.apple.com/design/human-interface-guidelines/playing-haptics, developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)

---

## 7. Loading state transitions

The HIG (Loading) is concise: *"use placeholder text, graphics, or animations to identify where content isn't available yet, and replace these placeholder elements as the content loads."* It does not prescribe shimmer specifically, but it does prescribe **content-shaped placeholders**.

**Decision rule by expected duration:**

| Expected duration | Pattern | Why |
|---|---|---|
| < 1s | Nothing, or a fade-in on arrival. | A spinner that flashes for 300ms is worse than no indicator. |
| 1–10s | **Skeleton / shimmer placeholders** in the shape of the eventual content. | Reduces perceived wait, sets layout expectations, prevents a "pop" on arrival. |
| > 10s, indeterminate | `ProgressView()` (spinner). Optionally add a textual hint of what's happening. | Acknowledges the wait; indeterminate spinners are the right semantic. |
| Determinate, any length | `ProgressView(value:total:)`. | Always prefer determinate when you can compute progress. |

**For the hotel results list:** skeleton rows in the shape of a hotel card (image rect + two text lines + price slot), 4–6 of them, fading in on first appearance with `.smooth`. When real data arrives, cross-fade the skeletons out and the real rows in over ~0.2s. A subtle shimmer (animated linear gradient sweeping across the placeholder) is acceptable as long as it respects Reduce Motion (drop to a static placeholder).

**iOS 17+ has `.redacted(reason: .placeholder)`** — this is the system-blessed way to render skeleton content from a real view. Use it. Do not hand-roll gray rectangles when you can render the real row hierarchy with `.redacted`.

> Source: developer.apple.com/design/human-interface-guidelines/loading

---

## 8. Modal presentation timing

Stock SwiftUI / UIKit handles all of these. Match them; don't customize unless you have a strong reason.

| Presentation | System animation | Use when |
|---|---|---|
| `.sheet` | Slide up from bottom, non-bouncy spring (~0.4s feel). Background page recedes slightly with the iOS 15+ sheet style. | Most modal content. Default choice. |
| `.fullScreenCover` | Slide up, no background recession, opaque. Same spring. | When the modal is its own context (booking flow, video player). User won't see the parent. |
| `.popover` | Scale + fade from anchor point, ~0.2s. iPad/Mac primary; iOS adapts to a sheet by default. | Contextual menus tied to a specific element. |
| `.alert` / `.confirmationDialog` | System-controlled, do not customize. | Destructive confirmations, errors that block. |

**Engineering rules:**

- Don't replace `.sheet` with a custom slide-up `.transition` unless the content genuinely needs to break the sheet's affordances. The pull-to-dismiss gesture, the rounded top corners, the background recession, and the right haptic-on-dismiss all come for free.
- For partial-height sheets (hotel quick-look from the search row?), use `.presentationDetents([.medium, .large])` — iOS 16+ — instead of a custom modal.
- Don't animate *into* a sheet presentation with your own `withAnimation`. The system's sheet animation runs on its own timeline and you'll get fighting transitions.

---

## 9. Push / pop transitions

`NavigationStack` (iOS 16+) is the right tool. Defaults:

- **Push:** detail slides in from trailing edge over ~0.35s with a non-bouncy spring. The pushed-from view parallaxes left at a slower rate (this is the "depth" cue).
- **Pop:** mirrored. Interactive pop gesture (edge swipe) follows the finger and decides direction on release based on velocity + distance.

**When to customize (almost never):**

- Hero/matched-geometry transitions for a card → detail (e.g., the hotel card image expands into the detail header). Use `.matchedGeometryEffect` with `.smooth` or `.snappy`. This is one of the few cases where custom motion clearly serves the user — it preserves the user's spatial mental model.
- A "modal-like" push where you don't want the standard slide. Reach for `.fullScreenCover` instead — it's almost always what you actually wanted.

**Anti-patterns to avoid:**

- Wrapping `NavigationStack` push in a custom `withAnimation`. You'll desync from the system gesture-driven pop.
- Disabling the interactive pop gesture. Users reach for it reflexively; removing it is hostile.
- Custom `UIViewControllerAnimatedTransitioning` in a SwiftUI app. If you need this, you're fighting the framework.

---

## 10. Performance budget per frame

The math, which is the only thing that matters here:

| Refresh rate | Frame budget | Where it shows up |
|---|---|---|
| 60 Hz | **16.67 ms** | iPhone SE, older iPads, all non-Pro iPhones pre-15 Pro. |
| 120 Hz (ProMotion) | **8.33 ms** | iPhone 13 Pro and later Pro models, iPad Pro. |

A "hitch" is any frame that misses its deadline. At 120 Hz, a frame that takes 9 ms instead of 8 ms is a hitch — even though it would have been comfortably on-budget at 60 Hz. **Design for the 8.33 ms budget.** If you hit that, 60 Hz is free.

**What this constrains in our hotel UI:**

1. **No layout work per frame.** Anything inside an animated property must not trigger a `Layout` re-computation. That means no `GeometryReader` driving an animated value; no `frame(width: animatedValue)` on a parent that has flexible children. Animate `scaleEffect`, `opacity`, `offset`, and `rotationEffect` — these are GPU-side compositor properties.
2. **Image decoding is the #1 hitch source on a card list.** Decode hotel images off the main thread (use `AsyncImage` with caution; for production, prefer Nuke / SDWebImage / a custom downsampling pipeline). Render to the row's actual pixel size, not full resolution.
3. **No shadows on scrolling content.** `.shadow(...)` on every card forces an off-screen render pass per frame. If the design needs shadow depth, use a pre-rendered gradient or a static shadow image asset.
4. **Avoid overdraw.** A card that is `Color.white` background → `RoundedRectangle` overlay → image overlay → text overlay → another `Color.white.opacity(0.95)` overlay is drawing every pixel 4–5 times. The compositor will skip what it can, but each layer costs.
5. **`List` over `LazyVStack(ScrollView)`** for long, homogeneous content. `List` recycles cells; `LazyVStack` only lazily *creates* them — once on screen they stay in memory.
6. **Animations on a background-thread state change require care.** Always hop back to `MainActor` before mutating an `@State` / `@Published` that drives animation, or you'll get visual tears.

**Diagnostic loop:** Instruments → Animation Hitches template. Run on the lowest-spec device the app supports (typically a 60 Hz iPhone SE 2nd/3rd gen). If hitches show up at 60 Hz, do not bother profiling on ProMotion until they're gone.

---

## Recipes (drop-in)

### Recipe A — HotelRow as a Button with system-feeling press state

```swift
struct HotelCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

// Usage:
Button { vm.select(hotel) } label: { HotelRow(hotel: hotel) }
    .buttonStyle(HotelCardButtonStyle())
```

### Recipe B — Animated results list with stable IDs

```swift
List {
    ForEach(vm.results) { hotel in            // Hotel: Identifiable, stable id
        NavigationLink(value: hotel) {
            HotelRow(hotel: hotel)
        }
    }
}
.animation(.smooth, value: vm.results.map(\.id))
```

The `.animation(_, value:)` form animates only when the *identity set* changes — keystroke-driven re-sorts of the same set are silent.

### Recipe C — Skeleton loading with `.redacted`

```swift
Group {
    if vm.isLoading {
        ForEach(0..<5) { _ in
            HotelRow(hotel: .placeholder)
                .redacted(reason: .placeholder)
        }
    } else {
        ForEach(vm.results) { HotelRow(hotel: $0) }
    }
}
.animation(.smooth(duration: 0.2), value: vm.isLoading)
```

### Recipe D — Haptic on favorite toggle, not on row tap

```swift
struct FavoriteButton: View {
    @Binding var isFavorite: Bool
    var body: some View {
        Button { isFavorite.toggle() } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
        }
        .sensoryFeedback(.impact(.light), trigger: isFavorite)
    }
}
```

### Recipe E — Reduce-Motion-aware hero transition

```swift
@Namespace private var heroNS
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// In list:
HotelRow(hotel: hotel)
    .matchedGeometryEffect(id: hotel.id, in: heroNS, isSource: true)

// In detail (inside a NavigationStack destination):
HotelHeader(hotel: hotel)
    .matchedGeometryEffect(id: hotel.id, in: heroNS, isSource: false)
    .transaction { txn in
        txn.animation = reduceMotion ? .linear(duration: 0.2) : .smooth
    }
```

---

## TL;DR rules for this codebase

1. Use `Button` + `ButtonStyle`, never `onTapGesture` on a `VStack`.
2. Default to `.smooth`. Reach for `.snappy` on toggle-like state. Reach for `.bouncy` essentially never.
3. Wrap data-driven list changes in `withAnimation` only when *identity* changes; ignore content-only deltas.
4. Read `\.accessibilityReduceMotion` on every view that uses scale, parallax, or bounce. Replace with cross-fade or instant.
5. Use `.sensoryFeedback` (iOS 17+), not `UIImpactFeedbackGenerator`, in SwiftUI. One haptic per *meaningful* user action; never per scroll tick or per keystroke.
6. Skeleton with `.redacted(reason: .placeholder)` for loads ≥ 1s. Spinner for unknown / > 10s.
7. Don't customize sheet, push, or pop transitions without a written reason. The defaults are the brief.
8. Profile to 8.33 ms on the slowest-supported 60 Hz device first; ProMotion is a verification step, not a target.
9. When in doubt, do less. Apple's HIG: *"avoid making people spend extra time watching unnecessary motion every time they interact with something."*
