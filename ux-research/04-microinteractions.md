# Micro-Interactions: The Vocabulary of Quality

Micro-interactions are the difference between an app that *works* and an app that *feels expensive*. They are the silent contract between the interface and the user — every tap acknowledged, every gesture rewarded, every state transition narrated through motion and haptics. Done poorly, they go unnoticed. Done well, they become the reason a user trusts the product enough to hand over a credit card.

This document is a reference for the micro-interactions that move a SwiftUI iOS 17+ app from "shipped" to "considered." Each pattern includes a SwiftUI recipe and the rationale behind the specific values — because in micro-interactions, the difference between `0.95` and `0.97` is the difference between a button that feels like a button and a button that feels like jelly.

---

## 1. Scale-on-Tap: The Foundational Acknowledgment

Every tappable surface should respond to touch. Period. The question is *how much*.

**The Numbers:**
- `0.97` — The Apple standard for system buttons (`Button` style `.bordered`, `.borderedProminent`). Subtle enough to feel native, perceptible enough to register.
- `0.95` — Standard for cards, tiles, list rows, large tap targets. The slightly larger compression communicates "this is a substantial element you're pressing."
- `0.92` — Reserved for primary CTA buttons where you want a definite tactile sense. Use sparingly; on small elements this looks broken.
- `0.98` — For tiny controls (12-16pt icons) where deeper compression would look glitchy.
- Below `0.90`: Avoid. The element starts to feel like rubber — childish, not premium.

**Spring Physics:**

iOS 17+ gives you the modern spring API. The right values for tap feedback:

```swift
.animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
```

- `response`: 0.25–0.35s. Lower than 0.2s feels twitchy; above 0.4s feels laggy.
- `dampingFraction`: 0.55–0.7. Lower bounces more (playful, good for hearts/likes). Higher settles faster (utilitarian, good for buttons).

**Recipe — Press-and-hold scale modifier:**

```swift
struct PressableScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableScaleStyle {
    static var pressable: PressableScaleStyle { .init() }
    static func pressable(scale: CGFloat) -> PressableScaleStyle { .init(scale: scale) }
}

// Usage
Button("Book Now") { /* ... */ }
    .buttonStyle(.pressable(scale: 0.95))
```

For non-Button views (entire cards), use a long-press gesture or `.onTapGesture` paired with a state-driven `.scaleEffect`:

```swift
struct PressableCard<Content: View>: View {
    let content: Content
    var onTap: () -> Void
    @State private var isPressed = false

    init(onTap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.68),
                       value: isPressed)
            .onLongPressGesture(minimumDuration: 0.01,
                                maximumDistance: 50,
                                perform: onTap,
                                onPressingChanged: { isPressed = $0 })
    }
}
```

The `minimumDuration: 0.01` makes the gesture effectively immediate while still giving you `onPressingChanged` callbacks — the cleanest pattern for "tap with press state" in SwiftUI.

---

## 2. Haptic Feedback: When Silence Speaks Louder

Haptics are seasoning, not the meal. The most common mistake is using them on every interaction — within 30 seconds of use, the user's wrist is buzzing constantly and the feedback loses all meaning.

**The Decision Matrix:**

| Interaction | Haptic | Rationale |
|---|---|---|
| Standard button tap | `.light` impact | Acknowledges without intruding |
| Toggle switch flip | `.medium` impact | State change deserves more weight |
| Destructive confirm (delete) | `.heavy` impact | "You're sure, right?" |
| Picker scroll, segmented swap | `.selection` | Per-item tick, like a wheel |
| Form submit success | `.success` notification | Distinct double-pulse |
| Validation warning | `.warning` notification | Asymmetric, stands out |
| Error / failed action | `.error` notification | Triple-pulse, unmistakable |
| Long-press menu open | `.medium` impact | Marks transition into modal mode |
| Pull-to-refresh trigger | `.medium` impact at threshold | Confirms gesture commitment |
| Swipe-to-delete reveal | `.light` impact | When delete button locks in |
| Reaching scroll boundary | `.rigid` impact | Subtle "wall hit" |
| Drag-and-drop pickup | `.medium` impact | Mode change |
| Drag-and-drop drop | `.light` impact | Confirmation |

**When NOT to use haptics:**

- Scrolling. The phone shouldn't vibrate while a list moves.
- Typing. The keyboard handles its own feedback.
- Repeated micro-actions (incrementing a stepper rapidly — debounce or skip).
- When the device is in silent mode AND the user has disabled haptics in Accessibility.
- Background animations the user didn't initiate.
- Within 100ms of another haptic. They blur together and feel like a glitch.

**Pre-iOS 17 (UIKit bridge, still works):**

```swift
let generator = UIImpactFeedbackGenerator(style: .light)
generator.prepare() // Call ahead of time to reduce latency
generator.impactOccurred()
```

`.prepare()` is the trick most engineers miss — it warms up the Taptic Engine so the haptic fires within ~10ms instead of ~50ms. Call it on `onAppear` or just before the user is likely to trigger.

---

## 3. iOS 17 `.sensoryFeedback` Modifier — The Modern API

iOS 17 finally gave SwiftUI a first-class haptic API. Use this instead of `UIImpactFeedbackGenerator` whenever possible — it integrates with SwiftUI's data flow and respects accessibility settings automatically.

**Signature:**

```swift
.sensoryFeedback(_ feedback: SensoryFeedback, trigger: some Equatable)
```

The haptic fires whenever `trigger` changes. That's it. No prepare, no UIKit boilerplate.

**Full feedback type catalog:**

```swift
.sensoryFeedback(.success, trigger: didSubmit)
.sensoryFeedback(.warning, trigger: validationFailed)
.sensoryFeedback(.error, trigger: networkError)
.sensoryFeedback(.selection, trigger: selectedTab)
.sensoryFeedback(.increase, trigger: stepperValue)        // ascending pitch
.sensoryFeedback(.decrease, trigger: stepperValue)        // descending pitch
.sensoryFeedback(.start, trigger: didStartRecording)
.sensoryFeedback(.stop, trigger: didStopRecording)
.sensoryFeedback(.alignment, trigger: snappedToGuide)     // for drag/snap interactions
.sensoryFeedback(.levelChange, trigger: zoomLevel)
.sensoryFeedback(.impact, trigger: didTap)
.sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: didTap)
.sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: didTap)
```

**Conditional firing — only haptic on a specific transition:**

```swift
.sensoryFeedback(trigger: count) { oldValue, newValue in
    if newValue > oldValue { return .increase }
    if newValue < oldValue { return .decrease }
    return nil  // No haptic if equal
}
```

This is the killer feature. You can suppress haptics based on context, return different ones for different transitions, all in a closure.

**Real example — favorite toggle:**

```swift
@State private var isFavorited = false

Button { isFavorited.toggle() } label: {
    Image(systemName: isFavorited ? "heart.fill" : "heart")
}
.sensoryFeedback(trigger: isFavorited) { _, new in
    new ? .impact(weight: .medium) : .impact(weight: .light)
}
```

The favorite gets a meatier haptic than the unfavorite — communicating positive commitment without saying a word.

---

## 4. Long-Press Preview — The Quiet Showcase

Apple uses long-press preview throughout Photos, Mail, Messages. Airbnb uses it on listing cards to show a richer preview without committing to navigation. It's the "peek" pattern reborn for the post-3D-Touch era.

**SwiftUI's `.contextMenu` with preview (iOS 16+):**

```swift
listingCard
    .contextMenu {
        Button("Save", systemImage: "bookmark") { save() }
        Button("Share", systemImage: "square.and.arrow.up") { share() }
        Button("Hide", systemImage: "eye.slash", role: .destructive) { hide() }
    } preview: {
        ListingPreviewView(listing: listing)
            .frame(width: 320, height: 420)
    }
```

The `preview` parameter is what makes this premium. Without it, you get a context menu over a blurred background. With it, you get the Apple-style elevated card showing a hero preview while menu actions sit beneath.

**When to use `.contextMenu` vs `UIContextMenuInteraction`:**

- **`.contextMenu`:** SwiftUI-native, declarative, handles haptic + animation automatically. Use this 95% of the time.
- **`UIContextMenuInteraction` (UIKit bridge):** Use when you need fine control over the preview's transition animation, custom snapshot rendering, or interaction with UIKit collection/table views. Wrap with `UIViewRepresentable`.

**Tap-to-commit:**

If you want the preview to be tappable (like Photos, where tapping the preview pushes to detail), add a `primaryAction`:

```swift
.contextMenu {
    /* menu items */
} preview: {
    ListingPreviewView(listing: listing)
}
// Note: .contextMenu doesn't have primaryAction directly.
// For commit-on-tap, use the modifier's older form or wrap the preview in a Button.
```

For tap-on-preview navigation, the cleanest path remains a `NavigationLink` wrapping the entire row + a `.contextMenu` for the secondary actions.

**Haptic note:** `.contextMenu` fires its own haptic on engagement. Don't add a manual one.

---

## 5. Heart / Favorite Burst — The Dopamine Hit

This is the single most-imitated micro-interaction in iOS. Twitter's like, Instagram's heart, Apple's "Add to Favorites." The pattern:

1. Icon scales down (~0.85) on press.
2. Color crossfades (gray → red).
3. Icon scales up past 1.0 (~1.25) with a spring overshoot.
4. Optional particle/burst emanating outward.
5. Settles back to 1.0.

**The recipe:**

```swift
struct FavoriteButton: View {
    @State private var isFavorited = false
    @State private var animationTrigger = false

    var body: some View {
        Button {
            isFavorited.toggle()
            animationTrigger.toggle()
        } label: {
            ZStack {
                // Burst ring (only on favoriting)
                if isFavorited {
                    Circle()
                        .stroke(Color.pink.opacity(0.6), lineWidth: 2)
                        .scaleEffect(animationTrigger ? 2.0 : 0.5)
                        .opacity(animationTrigger ? 0 : 0.8)
                        .animation(.easeOut(duration: 0.6), value: animationTrigger)
                }

                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isFavorited ? .pink : .secondary)
                    .scaleEffect(isFavorited ? 1.0 : 1.0)
                    .symbolEffect(.bounce, value: animationTrigger)
                    .contentTransition(.symbolEffect(.replace.downUp))
            }
        }
        .sensoryFeedback(trigger: isFavorited) { _, new in
            new ? .impact(weight: .medium, intensity: 0.9) : .impact(weight: .light)
        }
    }
}
```

**iOS 17 secret weapon — `.symbolEffect(.bounce)`:** SF Symbols have built-in bounce, pulse, scale, and variable-color animations. For a heart that bounces on tap, you get the entire animation for free with one modifier. No keyframes, no spring config.

**`.contentTransition(.symbolEffect(.replace.downUp))`:** When the symbol changes from `heart` to `heart.fill`, this gives you a vertical wipe transition between the two icons. Premium, native, one line.

For a richer burst with multiple particles, use `Canvas` + `TimelineView` to render lightweight emanating dots. But 95% of cases are well-served by the recipe above.

---

## 6. Pull-to-Refresh Customization

The default `.refreshable` on a `List` or `ScrollView` (iOS 16+) gives you the system spinner. It works. It also looks like every other app.

**The default — keep it for prototypes:**

```swift
ScrollView {
    LazyVStack { /* content */ }
}
.refreshable {
    await viewModel.reload()
}
```

**Branded loader — full custom:**

You can't customize the system `.refreshable` indicator directly. To go custom, build a manual pull-to-refresh using `GeometryReader` + a coordinated state machine:

```swift
struct CustomRefreshScrollView<Content: View>: View {
    let onRefresh: () async -> Void
    @ViewBuilder let content: Content

    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false
    private let threshold: CGFloat = 80

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: geo.frame(in: .named("scroll")).minY
                    )
                }
                .frame(height: 0)

                VStack(spacing: 0) {
                    if pullOffset > 0 || isRefreshing {
                        BrandedLoader(progress: min(pullOffset / threshold, 1.0),
                                      isRefreshing: isRefreshing)
                            .frame(height: max(pullOffset, isRefreshing ? threshold : 0))
                    }
                    content
                }
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            guard !isRefreshing else { return }
            pullOffset = max(0, offset)
            if offset > threshold {
                triggerRefresh()
            }
        }
        .sensoryFeedback(.impact(weight: .medium),
                         trigger: pullOffset > threshold)
    }

    private func triggerRefresh() {
        isRefreshing = true
        Task {
            await onRefresh()
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isRefreshing = false
                    pullOffset = 0
                }
            }
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
```

**The threshold haptic** — the `.sensoryFeedback` triggered on `pullOffset > threshold` is what makes the interaction feel committed. The user feels the moment refresh becomes inevitable. Without it, they don't know if pulling further does anything.

For the loader itself, brand-appropriate options:

- A logo that rotates as `pullOffset` increases (`rotationEffect(.degrees(progress * 360))`).
- A shimmer bar (see section 8).
- A bouncing dot loader.
- A lottie-style sequence keyed off progress.

---

## 7. Drag-to-Dismiss

Two flavors: sheet drag (vertical) and card swipe (horizontal).

**Sheet drag — iOS handles this for you in `.sheet` and `.fullScreenCover` with detents.** You almost never need custom drag-to-dismiss; the system gesture is best-in-class. Only build custom when you need a non-standard interaction (e.g., dismissing with a horizontal swipe, or a card that scales as it's dragged).

**Card swipe-to-archive recipe:**

```swift
struct SwipeToArchiveCard<Content: View>: View {
    let content: Content
    let onArchive: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isArchiving = false
    private let threshold: CGFloat = 120

    init(onArchive: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onArchive = onArchive
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Underlying archive indicator
            HStack {
                Spacer()
                Image(systemName: "archivebox.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(.trailing, 32)
                    .opacity(min(abs(dragOffset) / threshold, 1.0))
            }
            .background(Color.orange)

            // Foreground content
            content
                .background(Color(.systemBackground))
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Resist past threshold for tactile feel
                            let raw = value.translation.width
                            dragOffset = raw < 0 ? raw : raw * 0.3
                        }
                        .onEnded { value in
                            if value.translation.width < -threshold {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    dragOffset = -UIScreen.main.bounds.width
                                }
                                isArchiving = true
                                onArchive()
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
        }
        .sensoryFeedback(.impact(weight: .light),
                         trigger: abs(dragOffset) > threshold)
    }
}
```

**The resistance trick** — multiplying by `0.3` when dragging in the "wrong" direction creates physical resistance. This is what Apple does in scroll views and what gives the gesture its premium feel. Linear drag past a threshold feels broken; resisted drag feels alive.

For lists specifically, prefer `.swipeActions` — it handles all of this natively:

```swift
List {
    ForEach(items) { item in
        ItemRow(item: item)
            .swipeActions(edge: .trailing) {
                Button("Archive", systemImage: "archivebox") { archive(item) }
                    .tint(.orange)
            }
    }
}
```

---

## 8. Skeleton Shimmer Loading

The silver-gradient sweep across placeholder shapes. It signals "content is coming, hold steady" without spinning a generic loader.

**Simple recipe — masked LinearGradient:**

```swift
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(0.0),
                        .white.opacity(0.5),
                        .white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .mask(content)
                .offset(x: phase * 300)
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4).repeatForever(autoreverses: false)
                ) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// Usage on a placeholder card
VStack(alignment: .leading, spacing: 12) {
    RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.2)).frame(height: 180)
    RoundedRectangle(cornerRadius: 4).fill(.gray.opacity(0.2)).frame(height: 16)
    RoundedRectangle(cornerRadius: 4).fill(.gray.opacity(0.2)).frame(width: 120, height: 12)
}
.shimmer()
```

**The pro version — Metal shader via `ShaderLibrary` (iOS 17+):**

For maximum performance and control over gradient angle, frequency, and falloff:

```swift
.colorEffect(
    ShaderLibrary.shimmer(
        .float(timeProgress),
        .float(0.3),  // band width
        .float(2.0)   // angle
    )
)
```

Paired with a `.metal` shader file. Worth doing if shimmer appears across many cards simultaneously — the GPU shader scales to dozens of instances at 120fps where the SwiftUI gradient version starts to chug.

For most product surfaces, the masked-gradient version is plenty.

---

## 9. Bottom Sheet with Detents

iOS 16 introduced `.presentationDetents`. iOS 17 added customization for handle, drag indicator, and background interaction. This is the modern bottom sheet — no more third-party libraries.

**Standard usage:**

```swift
.sheet(isPresented: $showFilters) {
    FiltersView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationCornerRadius(24)
        .presentationContentInteraction(.scrolls)
}
```

**Detent options:**

- `.medium` — half-screen
- `.large` — full-screen
- `.fraction(0.3)` — 30% of screen height
- `.height(280)` — fixed pt height
- `.custom(MyDetent.self)` — fully custom logic

**Custom detent example:**

```swift
struct CompactDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        max(180, context.maxDetentValue * 0.25)
    }
}

.presentationDetents([.custom(CompactDetent.self), .medium, .large])
```

**Key modifiers explained:**

- `.presentationBackgroundInteraction(.enabled(upThrough: .medium))` — Lets the user interact with content behind the sheet while it's at medium or smaller. This is how Apple Maps lets you pan the map with the search sheet half-open.
- `.presentationContentInteraction(.scrolls)` — When content reaches the top of its scroll, drag continues scrolling instead of resizing the sheet. Use `.resizes` for the opposite (gesture always resizes).
- `.presentationCornerRadius(24)` — Override the system's 10pt corner radius for a softer, more modern look.
- `.presentationBackground(.ultraThinMaterial)` — Frosted glass background for the sheet itself.

**Tracking the active detent:**

```swift
@State private var selectedDetent: PresentationDetent = .medium

.sheet(isPresented: $showSheet) {
    ContentView()
        .presentationDetents([.medium, .large], selection: $selectedDetent)
}
```

You can react to detent changes — useful for adjusting content density (show more rows when detent is `.large`).

---

## 10. Empty + Failed State Entrance Animations

Empty states are not blank screens. They're an opportunity to set tone. The entrance animation is what differentiates "the data didn't load" from "we got you, here's what to try."

**The pattern:**

1. Icon springs in from scale 0.8 with a slight bounce.
2. Headline fades + slides up from +12pt offset.
3. Body text fades + slides up, slightly delayed.
4. CTA button fades + slides up, further delayed.

```swift
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let cta: String?
    let action: (() -> Void)?

    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)
                .scaleEffect(hasAppeared ? 1.0 : 0.8)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.65)
                            .delay(0.05), value: hasAppeared)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .offset(y: hasAppeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.15),
                           value: hasAppeared)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .offset(y: hasAppeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.25),
                           value: hasAppeared)

            if let cta, let action {
                Button(cta, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                    .opacity(hasAppeared ? 1.0 : 0.0)
                    .offset(y: hasAppeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.4).delay(0.35),
                               value: hasAppeared)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { hasAppeared = true }
    }
}
```

**Why staggered delays matter:** When everything animates simultaneously, the eye doesn't know where to land. Stagger forces a reading order — icon first (orientation), title (what), message (why), action (next step). The cumulative duration should be under 800ms or it starts to feel slow.

**Failed state variant:** Same structure, swap icon to `exclamationmark.triangle`, color to `.orange` for warning or `.red` for error, and ensure the CTA is action-oriented ("Try Again" not "OK"). Add `.symbolEffect(.bounce, value: hasAppeared)` on the icon for an attention-grabbing hello.

---

## 11. Pagination Dot Indicators

Apple's `TabView` with `.page` style gives you indicators for free:

```swift
TabView {
    ForEach(images) { img in AsyncImage(url: img.url) }
}
.tabViewStyle(.page(indexDisplayMode: .always))
.indexViewStyle(.page(backgroundDisplayMode: .always))
.frame(height: 240)
```

**Limitations of the system indicator:** Color is inherited and hard to override per-context. Position is fixed at the bottom. Dot size and spacing are not customizable.

**Custom dots — when to bother:**

- The carousel sits on a colored or image background where system dots have contrast issues.
- You want a different shape (pills, varying widths for active state, progress bars).
- You want morphing transitions between dots.

**Recipe:**

```swift
struct PageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.white : Color.white.opacity(0.4))
                    .frame(width: index == current ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75),
                               value: current)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
```

The active dot stretches to a pill shape — Instagram does this. It's more identifiable than a slightly-larger circle and feels like a progress indicator without being one.

Combine with a `TabView` using `.page(indexDisplayMode: .never)` and overlay your custom indicator:

```swift
TabView(selection: $currentPage) {
    ForEach(images.indices, id: \.self) { i in
        AsyncImage(url: images[i].url).tag(i)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
.overlay(alignment: .bottom) {
    PageIndicator(count: images.count, current: currentPage)
        .padding(.bottom, 16)
}
```

---

## 12. Press-and-Hold Context Preview

This is the iMessage / Photos pattern: you press and hold an item, the rest of the screen blurs out, the item enlarges with a hovering menu of actions, and releasing either commits an action or returns to the screen.

**The good news:** SwiftUI's `.contextMenu(menuItems:preview:)` does this entirely for you (covered in section 4). The system handles:

- Background blur
- Element scale-up animation
- Haptic on engagement
- Menu positioning
- Dismissal behavior

**When you need full custom (matched geometry "hero" style):**

```swift
struct PressAndHoldPreview<Item: Identifiable, Preview: View>: View {
    let item: Item
    @ViewBuilder let preview: (Item) -> Preview
    @Namespace private var ns
    @State private var isShowingPreview = false

    var body: some View {
        ZStack {
            if !isShowingPreview {
                preview(item)
                    .matchedGeometryEffect(id: item.id, in: ns)
                    .onLongPressGesture(minimumDuration: 0.3) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isShowingPreview = true
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $isShowingPreview) {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .background(.ultraThinMaterial)
                    .onTapGesture { isShowingPreview = false }

                preview(item)
                    .matchedGeometryEffect(id: item.id, in: ns)
                    .scaleEffect(1.1)
            }
            .presentationBackground(.clear)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isShowingPreview)
    }
}
```

For most cases, lean on `.contextMenu` — the custom version is a lot of code to maintain for marginal differentiation.

---

## 13. Tap Target Sizing

Apple's HIG: minimum 44x44 points. This is non-negotiable — it's both a usability standard and a requirement for App Store accessibility review.

**The most common bug:** Icon button with a 20pt SF Symbol, no padding. Visual size 20pt, hit area 20pt. The user mis-taps constantly and blames the app.

**The fix — `.contentShape` for hit-area expansion:**

```swift
Button {
    /* action */
} label: {
    Image(systemName: "xmark")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 44, height: 44)  // Hit area
        .contentShape(Rectangle())     // Full frame is tappable
}
```

**Why `.contentShape`:** Without it, taps register only on the visible image pixels (the X glyph), not the full 44pt frame. `contentShape(Rectangle())` tells SwiftUI: "the entire frame is the tap target."

**Visual tightness with comfortable hit area:**

```swift
HStack(spacing: 8) {
    ForEach(actions) { action in
        Button { action.handler() } label: {
            Image(systemName: action.icon)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }
}
.padding(.horizontal, -8)  // Pull icons back to visual edge alignment
```

This pattern — large hit areas, negative margin to maintain visual layout — is the "secret" behind toolbars that look tight but tap reliably.

**Stepper, segmented, slider:** Use the system controls. They handle target sizing internally.

**Lists:** Use `.listRowInsets` carefully — overly tight insets reduce row tap area below the 44pt minimum.

**Accessibility audit:** In Xcode, run the Accessibility Inspector and use the "Audit" feature. It flags hit targets below 44pt automatically.

---

## Closing Notes

Micro-interactions aren't decoration. They're the language the app speaks when it's not actively talking. A button that scales to `0.97` says "I heard you." A `.medium` haptic on toggle says "this matters." A staggered empty-state entrance says "we considered this moment."

The temptation is to add motion and haptics everywhere. Resist. The richest products are paradoxically restrained — every haptic earns its place by being rare, every animation justifies itself by being meaningful. The user shouldn't notice your micro-interactions. They should notice that the app *feels right*, without being able to say why.

Build them once, build them well, codify them as reusable modifiers and button styles, and apply consistently across every surface. That consistency is what crosses the threshold from "polished" to "premium."
