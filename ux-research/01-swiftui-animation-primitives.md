# SwiftUI Animation & Transition Primitives — Engineering Brief

**Target:** iOS 17+ / Swift 5.9 / SwiftUI 5
**Audience:** ResortPass app team, working on hotel cards, place rows, and state transitions
**Scope:** API-level guidance with production-grade defaults. Not a survey — a working reference.

---

## 1. `matchedGeometryEffect` — Hero Transitions Without UIKit

`matchedGeometryEffect` interpolates a view's geometry (frame, position, size) between two render passes that share an `id` inside a common `@Namespace`. It is the only first-party SwiftUI primitive for "shared element" / hero animations.

### When to use

- Tapping a hotel card in a list and having its hero image expand into the detail view.
- Promoting a place row's thumbnail into a full-screen gallery.
- Animating a price chip from a card into a sticky bottom bar on selection.

### When NOT to use

- Cross-`NavigationStack` pushes. `matchedGeometryEffect` cannot bridge across two views that aren't simultaneously in the view tree. Push transitions tear down the source view before the destination mounts. Use a `.fullScreenCover` or an overlay-based pseudo-navigation if you need the hero effect.
- Anything where the source and destination aren't structurally similar (a tiny chip morphing into a 16:9 image will warp ugly).

### Identifier strategy

The `id` must be:

1. **Stable across renders** — derive from the model's stable identity (`hotel.id`, not `UUID()` per render).
2. **Unique within the namespace** — namespace per logical "hero set." For a single list-to-detail transition, one namespace is fine. For nested heros (image AND price chip), use the same namespace with different ids.
3. **Type-erased carefully** — `id` is `AnyHashable`. Prefer concrete types like `String` or your model's typed ID; mixing types under the same namespace silently breaks matching.

```swift
struct HotelListView: View {
    @Namespace private var heroNS
    @State private var selected: Hotel?

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(hotels) { hotel in
                        HotelCard(hotel: hotel, namespace: heroNS)
                            .onTapGesture {
                                withAnimation(.snappy(duration: 0.35)) {
                                    selected = hotel
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }

            if let selected {
                HotelDetailView(hotel: selected, namespace: heroNS) {
                    withAnimation(.snappy(duration: 0.35)) {
                        self.selected = nil
                    }
                }
                .transition(.opacity) // background scrim fade
            }
        }
    }
}

struct HotelCard: View {
    let hotel: Hotel
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: hotel.imageURL) { $0.resizable() } placeholder: { Color.gray.opacity(0.1) }
                .matchedGeometryEffect(id: "image-\(hotel.id)", in: namespace)
                .aspectRatio(16/9, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(hotel.name)
                .matchedGeometryEffect(id: "title-\(hotel.id)", in: namespace)
                .font(.headline)
        }
    }
}
```

### Gotchas

- **`isSource:` parameter.** When two views with the same id are present simultaneously, exactly one should be `isSource: true`. The other reads geometry from it. Default is `true`. If both are sources you get jitter; if neither is, you get zero-frame collapse.
- **Identity churn during animation kills the effect.** If your `ForEach` re-keys mid-animation (e.g., the model is reloaded with new objects), the source view unmounts and the hero snaps. Stabilize identity before triggering.
- **Z-ordering.** The morphing view inherits the z-order of the destination. Wrap in a `ZStack` and ensure the destination is on top, or it animates behind the list.
- **Don't put `matchedGeometryEffect` on a `Group`.** Groups don't render geometry. Apply it to the actual leaf view (the image, the text, the rounded rectangle).

### Performance

- Each matched pair adds a layout pass per frame during the transition. Keep matched leaves to single digits — image, title, price chip. Don't match every label.
- Avoid `matchedGeometryEffect` on views inside a `LazyVStack` cell that's about to be recycled — the effect requires both endpoints to exist; if the source scrolls offscreen and is unmounted, the morph collapses to nothing.

---

## 2. `withAnimation` vs `.animation(_:value:)` — When Each Is Correct

Both still ship and both are still correct in iOS 17. The deprecation noise people remember is `.animation(_:)` (the unary form, no `value:`), which was deprecated in iOS 15 and remains so. The two-arg `.animation(_:value:)` is fine.

### `withAnimation { ... }`

**Imperative.** Wraps a state mutation; any view whose body depends on that state animates the resulting transaction.

Use when:

- The mutation is in an event handler (tap, gesture end, network completion).
- You want one explicit animation to drive multiple unrelated views.
- The trigger is in a `Task`, async closure, or callback — anywhere outside the view hierarchy's evaluation.

```swift
Button("Reserve") {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        viewModel.confirmReservation()
    }
}
```

### `.animation(_:value:)`

**Declarative.** Attached to a view; whenever `value` changes, animate this view's body re-render.

Use when:

- The state changes from somewhere you don't control (parent injection, `@Published` from a store).
- You want different views to animate the same state change with different curves.
- You want to scope animation precisely to one subtree without bleeding to siblings.

```swift
HotelCard(hotel: hotel)
    .scaleEffect(isPressed ? 0.97 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
```

### The deprecated form to avoid

```swift
.animation(.easeInOut)   // DEPRECATED. Animates everything that ever changes on this view.
```

This caused unintended animations on initial layout and made debugging brutal. Always pass `value:`.

### Heuristic

If the state mutation site is yours (you're writing the assignment), use `withAnimation`. If you're observing an external value flow into the view, use `.animation(_:value:)`. Mixing both on the same property is fine and sometimes correct (gesture handler uses `withAnimation` for the drop, while a parent-driven value uses `.animation(_:value:)`).

---

## 3. Animation Curve Choices — iOS 17 Additions

iOS 17 added four curated spring presets that read as "Apple-native": `.smooth`, `.snappy`, `.bouncy`, plus the existing `.spring(...)` got a cleaner overload. They're tuned the way Apple's own apps animate.

| Curve | Feel | Default duration | Use for |
|---|---|---|---|
| `.smooth` | No bounce, ease-like, calm | 0.5s | Sheet present, content reveal, layout shift |
| `.snappy` | Subtle overshoot, decisive | 0.5s | Tap feedback, selection, navigation |
| `.bouncy` | Pronounced overshoot, playful | 0.5s | Success states, celebratory, marketing moments |
| `.spring(response:dampingFraction:)` | Tunable | varies | Anything custom |

All three accept `(duration:extraBounce:)` to taste:

```swift
.smooth(duration: 0.35, extraBounce: 0)    // tighter, calmer
.snappy(duration: 0.3, extraBounce: 0.1)   // crisper button
.bouncy(duration: 0.6, extraBounce: 0.2)   // more rubber
```

### What feels "Apple-native"

- **Tap feedback (button press, card tap):** `.snappy(duration: 0.3)` or `.spring(response: 0.3, dampingFraction: 0.7)`. Settles in a quarter-second, slight overshoot reads as physical.
- **State transitions (loading → loaded, error → retry):** `.smooth(duration: 0.4)`. No bounce — a bouncing error message feels wrong.
- **Sheet/modal present:** `.smooth(duration: 0.5)`. This matches the system sheet curve closely.
- **Card insertion / list shuffle:** `.snappy(duration: 0.4)`. Quick enough not to delay, characterful enough to register.
- **Hero transitions:** `.snappy(duration: 0.35)`. Hero animations need to feel decisive; `.smooth` reads sluggish at hero scale.

Avoid `.linear` and `.easeIn` for anything user-facing. They feel mechanical. `.easeOut` is acceptable for something disappearing. Springs are almost always better.

---

## 4. `AnyTransition` Customization

Transitions describe how a view enters and leaves the hierarchy (insertion / removal), not how its properties change between renders. Used with `.transition(...)` on a view that conditionally appears.

### Built-ins

- `.opacity` — fade
- `.scale` (with optional `scale:` and `anchor:`) — grow/shrink
- `.move(edge:)` — slide from an edge
- `.slide` — convenience for slide from leading
- `.offset(...)` — by a CGSize
- `.push(from:)` — iOS 17, edge-to-edge push (not navigation-stack push)

### Combining

```swift
.transition(.opacity.combined(with: .move(edge: .bottom)))
```

### Asymmetric (different in/out)

```swift
.transition(
    .asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .opacity
    )
)
```

This is the pattern for a toast: slide in from bottom + fade in, then just fade out (sliding out reads as "I'm leaving the screen" — fading reads as "I'm done").

### Custom transitions (iOS 17)

iOS 17 introduced `Transition` protocol — the modern replacement for `AnyTransition` extensions. Cleaner, supports phases.

```swift
struct BlurFadeTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : 20)
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : 1.05)
    }
}

extension Transition where Self == BlurFadeTransition {
    static var blurFade: BlurFadeTransition { BlurFadeTransition() }
}

// Usage
view.transition(.blurFade)
```

`TransitionPhase` is `.willAppear`, `.identity`, `.didDisappear` — letting you build true three-phase transitions instead of binary in/out.

### Transition gotchas

- **Transitions only fire when paired with an animation context.** A plain `if` toggle that adds/removes a view does nothing visible without `withAnimation` or `.animation(_:value:)` on a containing view.
- **Transition is on the view being added/removed**, not its parent. If a `VStack { if x { Foo() } }` doesn't animate, put the transition on `Foo`, not `VStack`.
- **Transitions inside a `LazyVStack` for cell insertion are unreliable.** Lazy containers may instantiate cells outside the animation scope. Use `List` for reliable row-insertion animations, or accept that a `LazyVStack` insert just appears.

---

## 5. Spring Tuning — Sensible Defaults

Three knobs:

- **`response`** — duration of one full oscillation, in seconds. Smaller = stiffer/faster spring. Range: 0.1 (very stiff) to 1.0 (loose).
- **`dampingFraction`** — 0 = forever bouncing, 1 = no bounce (critically damped). 0.7-0.85 reads "natural." Below 0.5 is comedic.
- **`blendDuration`** — for interrupted animations: how long to blend velocities when a new animation supersedes the current one. Usually leave at 0; raise to 0.1-0.2 for gesture-driven things being re-grabbed mid-flight.

### Defaults for ResortPass

```swift
extension Animation {
    // Tap feedback — buttons, card press, chip select
    static let rpTap = Animation.spring(response: 0.3, dampingFraction: 0.75)

    // State transitions — loading -> content, content -> error
    static let rpState = Animation.smooth(duration: 0.4)

    // Modal/sheet — present and dismiss
    static let rpModal = Animation.smooth(duration: 0.5)

    // Card insertion / list reorder
    static let rpCard = Animation.spring(response: 0.45, dampingFraction: 0.85)

    // Hero transition (list -> detail morph)
    static let rpHero = Animation.snappy(duration: 0.35)

    // Interactive (gesture-attached)
    static let rpInteractive = Animation.interactiveSpring(response: 0.25, dampingFraction: 0.85, blendDuration: 0.1)
}
```

`.interactiveSpring` is tuned for gesture-driven motion — it's stiffer and snappier so the view feels "stuck to the finger." Use it inside `.onChanged`. Switch to a regular spring on `.onEnded`.

### Calibration heuristic

If an animation feels slow, lower `response` before raising `dampingFraction`. If it feels jittery, raise `dampingFraction` first. If it feels lifeless, lower `dampingFraction` to 0.7 before reaching for `.bouncy`.

---

## 6. Reduce Motion Accessibility

iOS exposes the user's "Reduce Motion" preference. SwiftUI does NOT auto-respect it for your custom animations — you must check.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

### When to disable entirely

- Parallax, oscillation, decorative loops.
- Bouncy springs (`.bouncy`, low damping). Replace with `.smooth` or remove.
- Hero transitions that scale/translate large distances.

### When to simplify, not remove

- State changes (loading → loaded). Keep an opacity crossfade — removing the transition entirely means content "pops" jarringly. Reduce Motion users still want graceful state changes; they just don't want spring oscillation.
- Sheet present/dismiss. Keep the present (system handles it), but skip your in-content animations.

### Pattern

```swift
struct HotelCard: View {
    let hotel: Hotel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? .linear(duration: 0.15) : .rpTap, value: isPressed)
    }
}
```

Helper:

```swift
extension Animation {
    static func accessible(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : animation
    }
}
```

For transitions, swap the curve, not the existence:

```swift
.transition(reduceMotion ? .opacity : .asymmetric(
    insertion: .move(edge: .bottom).combined(with: .opacity),
    removal: .opacity
))
```

---

## 7. Gesture-Driven Animation

The pattern: gesture writes to `@GestureState` or `@State` continuously during interaction (no animation, view follows finger), then snaps to a resting state with a spring on release.

### Drag-to-dismiss sheet

```swift
struct DismissibleSheet<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        content()
            .offset(y: max(0, dragOffset))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let predicted = value.predictedEndTranslation.height
                        if predicted > 200 {
                            withAnimation(.smooth(duration: 0.35)) {
                                dragOffset = 1000
                            } completion: {
                                onDismiss()
                            }
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }
}
```

Notes:

- `predictedEndTranslation` uses velocity to project where the finger would end up if released — this is how you get "flick to dismiss" feeling correct, not just "dragged past threshold."
- iOS 17's `withAnimation(_:completion:)` overload lets you chain post-animation work cleanly. Pre-iOS 17 required `DispatchQueue.main.asyncAfter` with the duration estimated.
- During `onChanged`, never animate the offset assignment — the view should track the finger 1:1.

### Tap-to-scale with gesture state

```swift
struct PressableCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @GestureState private var isPressed = false

    var body: some View {
        content()
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.rpTap, value: isPressed)
            .gesture(
                LongPressGesture(minimumDuration: 0.01)
                    .updating($isPressed) { _, state, _ in state = true }
            )
    }
}
```

`@GestureState` auto-resets when the gesture ends — you get press-down and release-up animation for free without writing release handlers.

---

## 8. Performance Pitfalls

Choppy SwiftUI animations almost always come from one of these:

### 1. Animating views inside `GeometryReader` inside a `ForEach`

`GeometryReader` forces layout on every parent change. Inside a `ForEach`, each row gets its own reader, multiplying layout work. If you must read geometry per cell, prefer `.onGeometryChange(for:of:action:)` (iOS 17+) which is observation-based and far cheaper:

```swift
.onGeometryChange(for: CGSize.self) { proxy in
    proxy.size
} action: { newSize in
    // handle
}
```

### 2. Transient subview identity

If a cell's body returns a different view structure when state changes (e.g., `if isLoading { Spinner() } else { Content() }`), SwiftUI tears down and remounts. Mounting during animation = pop, not transition. Wrap with `.transition(.opacity)` or restructure so the same view shape persists with conditional content.

### 3. `Group` and unstable identity

`Group` doesn't change rendering but it changes diffing in subtle ways. Avoid wrapping animated subtrees in `Group` if you can use a concrete container. More importantly: `ForEach(items.indices, id: \.self)` is a perf bug — use `ForEach(items)` with `Identifiable` so identity tracks the model, not the position. Otherwise every reorder looks like delete-all + insert-all.

### 4. `AsyncImage` re-creating during animation

`AsyncImage` re-fetches if its identity changes mid-animation. If a card image is animating and the view re-renders with a slightly different URL (signed URL refresh, query param), you'll get a flash. Stabilize the URL before passing it in.

### 5. Animating expensive modifiers

`.shadow`, `.blur`, `.background(.ultraThinMaterial)` are GPU-bound. Animating them at 60+fps on older devices stutters. If you must, animate them with `drawingGroup()` to flatten to a single layer:

```swift
view.shadow(radius: shadowRadius)
    .drawingGroup()
```

`drawingGroup()` rasterizes to an offscreen layer — cheap to animate position/scale, expensive to invalidate. Use sparingly.

### 6. List vs LazyVStack

`List` uses UIKit `UITableView` underneath in iOS 17 and gets row insert/delete animations for free. `LazyVStack` uses pure SwiftUI lazy layout — faster scroll, weaker animation guarantees. For ResortPass: use `List` when you want row-level animations (insert, delete, reorder). Use `LazyVStack` when you control animations explicitly per-row and want full styling control.

---

## 9. Concrete Recipes

### 9.1 Tap-to-scale (0.97 with spring)

```swift
struct ScaleOnPress: ViewModifier {
    @GestureState private var isPressed = false
    var scale: CGFloat = 0.97

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isPressed)
            .gesture(
                LongPressGesture(minimumDuration: 0.01)
                    .updating($isPressed) { _, state, _ in state = true }
            )
    }
}

extension View {
    func scaleOnPress(_ scale: CGFloat = 0.97) -> some View {
        modifier(ScaleOnPress(scale: scale))
    }
}

// Usage
HotelCard(hotel: hotel)
    .scaleOnPress()
    .onTapGesture { selectHotel(hotel) }
```

### 9.2 Image fade-in

```swift
struct FadeInImage: View {
    let url: URL?
    @State private var loaded = false

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .opacity(loaded ? 1 : 0)
                    .onAppear {
                        withAnimation(.smooth(duration: 0.3)) { loaded = true }
                    }
            case .empty, .failure:
                Color.gray.opacity(0.1)
            @unknown default:
                Color.gray.opacity(0.1)
            }
        }
    }
}
```

### 9.3 Sheet present / dismiss

System `.sheet` handles the present animation. To customize content reveal inside:

```swift
.sheet(isPresented: $showing) {
    HotelDetailSheet()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
}
```

For full custom (background scrim, custom curve), build a ZStack overlay:

```swift
ZStack {
    mainContent
    if showing {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .transition(.opacity)
            .onTapGesture {
                withAnimation(.smooth(duration: 0.35)) { showing = false }
            }
        SheetContent()
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
.animation(.smooth(duration: 0.45), value: showing)
```

### 9.4 Push transition customization

`NavigationStack` push animation is not customizable in iOS 17 — Apple owns it. If you need custom push, fake it with a ZStack overlay and a slide transition:

```swift
ZStack {
    listView
    if let detail = pushedDetail {
        detailView(detail)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .trailing)
            ))
            .zIndex(1)
    }
}
.animation(.smooth(duration: 0.4), value: pushedDetail)
```

This loses `NavigationStack`'s back-swipe and toolbar integration. Trade-off: only do this when the design genuinely demands it, e.g., for a hero transition that the system push can't accommodate.

### 9.5 List-row insertion

```swift
List {
    ForEach(places) { place in
        PlaceRow(place: place)
            .transition(.asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .opacity
            ))
            .listRowSeparator(.hidden)
    }
}
.animation(.spring(response: 0.45, dampingFraction: 0.85), value: places.map(\.id))
```

The `value:` is the array of ids — animation triggers when the set of identities changes, not when the array reference changes. This is critical for stores that re-emit identical content.

### 9.6 Loading -> Loaded crossfade

```swift
ZStack {
    if isLoading {
        SkeletonHotelList()
            .transition(.opacity)
    } else {
        HotelList(hotels: hotels)
            .transition(.opacity)
    }
}
.animation(.smooth(duration: 0.3), value: isLoading)
```

### 9.7 Empty / error state morph

```swift
Group {
    switch state {
    case .loading: SkeletonView()
    case .loaded(let hotels): HotelList(hotels: hotels)
    case .empty: EmptyStateView()
    case .error(let err): ErrorStateView(error: err)
    }
}
.transition(.opacity.combined(with: .scale(scale: 0.98)))
.animation(.smooth(duration: 0.3), value: state.identifier)
```

Where `state.identifier` is a stable hashable representing the case — not the associated value, so the same case with different data doesn't re-animate.

---

## 10. iOS 17-Specific Affordances

### `phaseAnimator`

Cycles a view through a sequence of phases on a trigger. Good for repeating attention-getting animations that aren't tied to user state — e.g., a "live" indicator pulsing.

```swift
Circle()
    .fill(.green)
    .frame(width: 8, height: 8)
    .phaseAnimator([1.0, 1.4, 1.0]) { circle, scale in
        circle.scaleEffect(scale)
    } animation: { _ in
        .smooth(duration: 0.6)
    }
```

For trigger-based one-shot phase sequences, use the trigger overload:

```swift
.phaseAnimator([0, 1, 0], trigger: confirmTapped) { content, phase in
    content.opacity(1 - phase)
}
```

### `keyframeAnimator`

For complex multi-property animations that need precise timing — a "celebration" or onboarding moment. You define keyframes per animatable property and SwiftUI interpolates.

```swift
struct CelebrationProperties {
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var opacity: CGFloat = 1.0
}

view.keyframeAnimator(initialValue: CelebrationProperties(), trigger: confirmed) { content, props in
    content
        .scaleEffect(props.scale)
        .rotationEffect(props.rotation)
        .opacity(props.opacity)
} keyframes: { _ in
    KeyframeTrack(\.scale) {
        SpringKeyframe(1.2, duration: 0.2)
        SpringKeyframe(1.0, duration: 0.3)
    }
    KeyframeTrack(\.rotation) {
        CubicKeyframe(.degrees(-5), duration: 0.1)
        CubicKeyframe(.degrees(5), duration: 0.2)
        CubicKeyframe(.zero, duration: 0.2)
    }
}
```

Don't reach for keyframes when a spring will do. Reserve for genuinely choreographed moments — booking confirmation, achievement unlocks, the brand "moment."

### Custom timing curves

```swift
.animation(.timingCurve(0.2, 0.0, 0.0, 1.0, duration: 0.4), value: x)
```

The four params are the cubic-Bezier control points (matching CSS `cubic-bezier`). Useful when design hands you a curve from After Effects or when matching a brand motion guideline. For most cases, prefer the spring presets — they survive interruption gracefully, timing curves don't.

### `withAnimation(_:completion:)`

iOS 17 finally added a completion handler:

```swift
withAnimation(.smooth(duration: 0.3)) {
    isExpanded = true
} completion: {
    sendAnalyticsEvent("card_expanded")
}
```

Replace any `DispatchQueue.main.asyncAfter(deadline: .now() + duration)` chain you previously used for post-animation work.

### `Transition` protocol (covered in §4)

The modern way to author custom transitions, with phase awareness.

### `.scrollTransition`

Lets you animate views as they enter/exit the visible scroll area:

```swift
ScrollView {
    LazyVStack {
        ForEach(hotels) { hotel in
            HotelCard(hotel: hotel)
                .scrollTransition(.animated(.smooth)) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.6)
                        .scaleEffect(phase.isIdentity ? 1 : 0.95)
                }
        }
    }
}
```

Excellent for hotel list "depth" feel — cards subtly scale and fade as they approach/leave the viewport edges.

### `.symbolEffect`

For SF Symbols only — animated icon transitions (bounce, pulse, variableColor, replace). Use on heart icons (favorite toggle), live state indicators, refresh buttons.

```swift
Image(systemName: isFavorited ? "heart.fill" : "heart")
    .symbolEffect(.bounce, value: isFavorited)
    .contentTransition(.symbolEffect(.replace))
```

`.contentTransition(.symbolEffect(.replace))` is the killer one — SF Symbol-aware morph between two icons. Read this twice: it's a `contentTransition`, not a `transition`. It applies inside `Text`/`Image` content changes, not view insertion/removal.

---

## Quick Reference — Picking The Right Tool

| Goal | Tool |
|---|---|
| Animate a value change you're driving in a closure | `withAnimation(.snappy) { state.x = y }` |
| Animate a value change driven externally | `.animation(.smooth, value: x)` on the view |
| Animate view enter/exit | `.transition(...)` + animation context |
| Shared-element morph between two views | `matchedGeometryEffect` + `@Namespace` |
| Tap feedback (scale down) | `@GestureState` + `LongPressGesture` + `.spring` |
| Drag-to-dismiss | `DragGesture` + `predictedEndTranslation` + `.spring` on release |
| Multi-step choreography | `keyframeAnimator` |
| Repeating subtle attention cue | `phaseAnimator` |
| Animate icon swap | `.contentTransition(.symbolEffect(.replace))` |
| Scroll-driven fade/scale | `.scrollTransition` |
| Post-animation callback | `withAnimation(_:completion:)` |
| Respect user a11y | `@Environment(\.accessibilityReduceMotion)` |

---

## Defaults To Adopt In ResortPass

1. Define `Animation.rpTap`, `.rpState`, `.rpModal`, `.rpCard`, `.rpHero`, `.rpInteractive` in a single `Animation+ResortPass.swift`. Forbid one-off magic numbers in PRs.
2. Build `.scaleOnPress()` modifier and apply to every tappable surface (cards, rows, chips). Single line per call site.
3. Wrap every animation call in a Reduce-Motion-aware helper, or use `@Environment(\.accessibilityReduceMotion)` at the modifier site.
4. Use `List` for hotel/place row lists where insertion/deletion animations matter. Use `LazyVStack` only when you need full custom row layout.
5. Stabilize identity end-to-end: `Identifiable` models, no `id: \.self` on indices, no `UUID()` in view bodies.
6. Reserve `keyframeAnimator` for booking confirmation and onboarding moments. Springs everywhere else.
7. Hero transitions use ZStack overlay pattern with `matchedGeometryEffect`, not `NavigationStack` push.
8. Symbol icons (favorite, share, refresh) get `.symbolEffect` and `.contentTransition(.symbolEffect(.replace))` by default.
