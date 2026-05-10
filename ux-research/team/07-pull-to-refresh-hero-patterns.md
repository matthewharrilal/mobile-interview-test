# 07 — Pull-to-Refresh & Hero Parallax Patterns

The brief: a hotel listings detail screen with a parallax hero image. The current build shows a hard flat top edge under the status bar, and a white gap appears above the image when the user pulls down. This document catalogs how premium iOS apps solve both problems, then distills the adoptable patterns into concrete SwiftUI iOS 17+ recipes.

The two issues are actually one issue. A "white gap on pull-down" means the image's frame is fixed and the scroll container's background is showing through during overscroll. A "hard flat top edge" means the image is being clipped at the safe-area inset rather than bleeding under a translucent chrome layer. Premium apps fix both at once: the hero image bleeds edge-to-edge under a transparent navigation bar at rest, and on pull-down the image stretches its top edge upward (anchored at the bottom) so there is never a frame to expose.

---

## Reference Catalog

### 1. Apple Music — Album / Playlist Detail

**At rest:** The hero is a full-bleed square album artwork pinned to the top of a vertically scrolling content stack. The system navigation bar is fully transparent on first appearance — no blur, no border, no fill. The artwork bleeds under the status bar; only the back chevron and the share/more glyph float in the safe-area zone. A subtle vertical gradient (clear → background tint) fades the bottom 25% of the artwork into the track-list area so the title text stays legible without a hard edge.

**Pull down:** The artwork stretches. The bottom edge of the image stays pinned to its original Y position; the top edge tracks the finger past the safe-area inset, scaling the entire image larger uniformly. There is no gap. There is no clip. As pull distance grows, a very subtle Gaussian blur creeps in over the top 10–15% of pull (~30pt of overscroll triggers a noticeable softening) — this prevents the artwork from looking pixelated when stretched 1.3–1.5x.

**Pull up (scroll into content):** The artwork moves at scroll velocity until the title row crosses the nav bar baseline. At that point a `UIBlurEffect` with `.systemUltraThinMaterial` fades in over ~120ms behind the nav bar, the album title slides up to replace the navigation title, and a hairline `1px` separator becomes visible. Below the nav bar the artwork continues to scroll out of view at full speed (no parallax slow-down — Apple Music does NOT do "background moves slower than foreground" here).

**Implementation sketch:**
```swift
ScrollView {
    VStack(spacing: 0) {
        AsyncImage(url: album.artworkURL) { $0.resizable().scaledToFill() }
            .frame(height: UIScreen.main.bounds.width) // 1:1 square
            .stretchy()                                 // see Recipe A
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Color(.systemBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 80)
            }
        TrackList(...)
    }
}
.ignoresSafeArea(edges: .top)
.toolbarBackground(.hidden, for: .navigationBar)
.onScrollGeometryChange(for: CGFloat.self,
    of: \.contentOffset.y,
    action: { _, y in titleVisible = y > artworkHeight - 60 })
```

---

### 2. Apple Maps — Location Detail Card

**At rest:** Maps presents location details inside a sheet (`presentationDetents([.medium, .large])`) rather than a push, but the photography region at the top of the sheet behaves like a hero. At medium detent the photo grid is collapsed into a 4-up mosaic (220pt tall). The grid is anchored to the top of the sheet's content; the sheet's grabber sits over the photos with a translucent shadow plate behind it for legibility.

**Pull down:** Two-stage gesture. Below the photo grid, pull-down dismisses to medium detent. Within the photo grid itself, a horizontal swipe scrolls through more photos (no vertical stretch — vertical pulls drive sheet dismissal). This is a deliberate gesture handoff: the hero region opts out of vertical overscroll because the parent sheet owns that gesture.

**Nav handling:** No nav bar. The sheet's grabber + dismiss-X are the only controls. When you transition to `.large` detent, the sheet expands and a back chevron + share glyph appear inside a translucent capsule — never a full nav bar bar.

**Motion treatments:** None on the photos themselves. The sheet's spring (interactive dismiss) supplies the only motion. Apple Maps deliberately keeps the hero quiet because the map underneath is doing the visual work.

**Takeaway:** When the screen is presented as a sheet, do not stretch the hero on vertical pull — let the sheet handle that. The hero only stretches when the screen is pushed in a navigation stack.

---

### 3. Airbnb — Listing Detail

**At rest:** A 16:10 hero image fills width, bleeding under a transparent nav bar. A back chevron and a share/heart pair float in white circular pills with a `.regularMaterial` background (so they read on light or dark photography). A small "1 / 24" pagination chip floats at bottom-right of the hero with the same material.

**Pull down:** Classic stretchy header. The image scales from `.bottom` anchor — top edge tracks the finger. No blur. No ken-burns. Maximum stretch is uncapped but felt-capped by rubber-banding inside the ScrollView (`UIScrollView.bounces = true` equivalent). When the gesture releases, the image springs back over ~350ms with a `.spring(response: 0.4, dampingFraction: 0.8)` feel.

**Horizontal swipe on hero:** Inside the hero region, horizontal swipes page through the gallery. This nests a horizontal `TabView(selection:)` with `.tabViewStyle(.page)` inside the vertical ScrollView. The vertical pull-to-stretch is preserved on each page.

**Nav transition:** As the user scrolls past the hero, the nav bar transitions in three discrete phases:
1. `0 → heroHeight - 120pt`: nav fully transparent, pill-style controls visible.
2. `heroHeight - 120pt → heroHeight - 60pt`: the pill chrome morphs to a flat chevron, a `.regularMaterial` blur fades in behind the nav bar (opacity interpolated linearly), and the listing title fades in as the navigation title.
3. `> heroHeight - 60pt`: a hairline divider appears. The blur is fully opaque.

The morph in phase 2 is the signature Airbnb touch — the pill background fades while the chrome remains, so it looks like the buttons "shed their suit."

**Implementation notes:** The pill→flat morph is best done with two button instances cross-faded via `.opacity(progress)` driven by `onScrollGeometryChange`, NOT a continuous transformation. Looks identical, far simpler.

---

### 4. Spotify — Album Page

**At rest:** Square album art (380pt tall on iPhone 15 Pro) centered horizontally with ~40pt left/right gutters, sitting on a dynamic background gradient sampled from the artwork's dominant color (using `UIImage.averageColor` or accent extraction). The art is NOT bleeding under the nav bar — it sits below the safe area, with the gradient bleeding under a transparent nav bar above it.

**Pull down:** The album art does NOT stretch. Spotify takes a different approach: a small downward pull (0–60pt) does nothing visible; a larger pull triggers a haptic and scrolls past it. The gradient backdrop, however, expands to fill the overscroll zone — the gap is filled with the same color the user is already looking at, so there is no perceived gap.

**Pull up (the signature move):** As the user scrolls up, the album art does three things in lockstep:
- **Scale**: 1.0 → 0.6 over 224pt of scroll distance.
- **Translate**: drifts upward at ~1.4x scroll speed (faster than scroll), so it disappears off the top before its natural exit point.
- **Fade**: opacity 1.0 → 0.0 between scroll offsets [120, 224].

By the time the user has scrolled 224pt, the artist name, action buttons, and album art are gone. The play button sticks to the top and pins under the nav bar with a blur material behind it.

**Why it matters for hotel hero:** Spotify's "fill the gap with the gradient" is the single most adoptable trick if you do not want to implement a stretchy header. It eliminates the white-gap problem with one line of CSS-equivalent: place a same-colored view BEHIND the ScrollView, and let overscroll reveal it.

**Implementation sketch:**
```swift
ZStack {
    accentGradient.ignoresSafeArea() // fills overscroll regions
    ScrollView { ... }
}
```

---

### 5. Hopper — Hotel Detail

**At rest:** Full-bleed hero photo, 280pt tall, edge-to-edge, bleeding under a transparent nav bar. Hopper layers a subtle vignette (radial gradient from clear at center to ~12% black at the corners) to give the photography editorial weight without darkening the focal subject. Floating chrome: bunny mascot back glyph, share, heart — all in `.regularMaterial` capsules.

**Pull down:** Stretchy + light ken burns. At rest the image already has a slow zoom (1.0 → 1.05 over 8 seconds, eased with `.easeInOut`, ping-pong). On pull-down the stretch math takes over, multiplying with the ken-burns scale. Effect: the image feels alive even when idle.

**Below hero:** A characteristic Hopper move — a "watch this hotel for price drops" CTA with a bunny illustration sits 80pt down. As the user scrolls, the CTA slides up and pins to the bottom of the nav bar (under the blur) once the hero exits view. This is `safeAreaInset(edge: .top)` territory.

**Nav transition:** Same three-phase as Airbnb but Hopper uses a chunkier pixel-look hairline (2pt double-line) when the nav bar lock-in completes. Editorial signature.

**Ken burns math:**
```swift
.scaleEffect(burnsScale)
.onAppear {
    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
        burnsScale = 1.05
    }
}
```

---

### 6. HotelTonight — Booking Detail

**At rest:** Photo carousel as the hero (16:9, ~240pt). Page indicator dots in the photo's bottom 12pt safe inset. The photo bleeds under the nav bar; back chevron is a single white glyph with a radial shadow underneath (no pill, no material). Editorial-loud.

**Pull down:** No stretch. HotelTonight is a velocity-and-conversion product, not an editorial product, so they kill overscroll entirely — `bounces = false`. There is no white gap because there is no overscroll to expose. This is a legitimate option: turn off the gesture rather than animate it.

**Scroll up:** Photo carousel does NOT parallax. It scrolls at 1.0x with the rest of the content. Nav bar fades in a `.regularMaterial` blur around 60pt of scroll offset.

**Why it matters:** Sometimes the right answer is to disable overscroll. A hotel app focused on "tonight's deal" doesn't need editorial flourish — it needs frictionless tap-to-book. If that's the brief, `.scrollBounceBehavior(.basedOnSize)` or disabling bounce on the outer ScrollView is the simplest fix.

---

### 7. Threads / Twitter (X) — Profile Banner

**At rest:** A short banner image (~120pt tall, 3:1 aspect) with the avatar overlapping its bottom edge in a circular crop. Banner bleeds under a transparent nav bar.

**Pull down:** The most aggressive stretch in this catalog. Twitter's banner uses an `endScale` of ~6x at full pull — meaning if the user pulls down by 43% of the banner height, the banner has scaled 6x. This is way past photographic acceptability, so they layer a progressive blur:
- **Scale**: 1.0 → 6.0, anchor `.bottom`
- **Blur**: 0 → ~20pt radius, interpolated against scrollY mapped from [0, 40] → [0, 1]
- **Result**: A pull at maximum looks like an out-of-focus color field. The banner remains identifiable but no individual pixels are objectionable.

**Avatar choreography:**
- **Scale on pull**: 1.0 → 1.0 (avatar stays put — only banner stretches)
- **Scale on scroll up**: maps scrollY [0, AVATAR_SIZE] to scale [1.0, 0.5]
- **Translate**: avatar shifts up by half its own size to stay perceptually anchored as it shrinks
- **Z-order flip**: when scaled below threshold, avatar moves BEHIND the nav bar (z-index swap)

**Nav bar:** When scrolled, the banner blurs to ~20pt radius and a `.systemThinMaterial` overlays. The user's display name fades in as the navigation title.

**Why it matters for hotel hero:** The blur-on-stretch idea is the killer detail. Stretching a photograph 1.5x is fine; 3x and beyond looks bad without blur. If you want unbounded stretch, layer in blur proportional to stretch amount.

---

### 8. Netflix / Disney+ — Title Detail

**At rest:** A vertical poster or a 16:9 still occupies the top half of the screen. A long vertical gradient scrim fades the bottom 60% of the image into the background color so title typography sits readably. The gradient is 3-stop, NOT 2-stop:
- 0% — clear
- 60% — 70% background
- 100% — 100% background

This non-linear stop curve is the editorial signature: a 2-stop gradient creates a perceptible "halfway line" where the gradient transitions; the 3-stop curve hides the transition by making the early portion almost invisible.

**Pull down:** Disney+ allows stretch with a soft cap (rubber-band), Netflix does not allow overscroll on this screen (`bounces = false` on the iOS app's title detail). Both are valid; Disney+ feels editorial, Netflix feels controlled.

**Nav handling:** Both apps make the back chevron a circular glyph with shadow (no pill). The nav bar never gets a blur — instead, when the user scrolls, the entire scrim region scrolls with the content, and the navigation chevron stays fixed in the safe area against whatever happens to be behind it. This works because the gradient scrim is dark enough that the chevron always reads.

**Implementation note:** The 3-stop scrim is the single most copyable element here. Always use it on top of editorial photography.

```swift
LinearGradient(
    stops: [
        .init(color: .clear, location: 0.0),
        .init(color: Color(.systemBackground).opacity(0.7), location: 0.6),
        .init(color: Color(.systemBackground), location: 1.0)
    ],
    startPoint: .top, endPoint: .bottom
)
```

---

### 9. Mr & Mrs Smith — Boutique Hotel Hero

**At rest:** Editorial-led. Hero image is full-bleed, often 4:5 aspect (taller than wide), under a transparent nav bar. The signature Smith move is type-on-photography: a serif italic hotel name overlays the bottom-left of the hero in white, with a hairline rule above it. No card, no pill, no blur — pure editorial layout. Below the hero, a thin "Wishlist" or "Book" tab capsule floats with a glass material.

**Pull down:** Stretches with ken-burns layered in. Smith's ken-burns is more aggressive than Hopper's — 1.0 → 1.08 over 12 seconds — and they offset the focal point slightly so it pans as well as zooms. The pull-down stretch is uncapped and unblurred (Smith trusts their photography to hold up to stretching, so they can avoid blur as a "safety net").

**Scroll behavior:** Hero exits at 1.0x scroll velocity. The hotel name and rule slide off with the image. A `.toolbarBackground(.visible, for: .navigationBar)` with a `Color.white` material kicks in around 60% of hero exit.

**Editorial signature:** Smith uses serifs (Tiempos / GT Sectra style), NEVER sans for the hero overtitle. This is a brand differentiator — you would not copy the typography, but the layered text-on-photography pattern is highly adoptable.

---

### 10. 60fps.design Catalog — Cross-App Motifs

A scan of premium iOS app animations on 60fps.design surfaces three repeating motifs that span hospitality, music, social, and editorial:

1. **Bottom-anchored stretch.** Every premium pull-down stretch I observed anchors at `.bottom`, not `.top` or `.center`. Anchoring at bottom keeps the content beneath the hero stationary; the user's eye reads the page as "the image is being pulled, not the page."

2. **Three-phase nav transition.** Transparent → blur fading in → blur with hairline. The third phase (hairline) is what separates "okay" implementations from "premium." Without it, the nav bar feels like it floats; with it, the bar feels structurally "locked" once content is underneath.

3. **Material chrome over photography.** Floating buttons over a hero image are almost always `.regularMaterial` or `.thinMaterial` capsules — NOT solid white circles, NOT shadowed glyphs. The material adapts to whatever image is underneath. This is one of those "looks the same in screenshots but feels completely different live" details.

---

## Summary — Top 3 Adoptable Patterns

### Pattern A — The Anchored Stretch (Airbnb / Apple Music)
**Adopt this first.** It directly fixes the white-gap problem.

The image is full-bleed, ignores the top safe area, sits under a transparent nav bar. On pull-down it scales from a `.bottom` anchor by an amount equal to the overscroll distance. There is no white gap because the image's frame is always at least as tall as it needs to be.

### Pattern B — The 3-Stop Editorial Scrim (Netflix / Disney+ / Smith)
The hero image gets a 3-stop linear gradient overlay at its bottom edge. This kills the "hard flat edge" complaint by softening the image-to-content transition. Always paired with Pattern A.

### Pattern C — The Three-Phase Nav (Airbnb / Hopper)
Three discrete phases driven by `onScrollGeometryChange`: transparent (over hero) → blur fade-in (transition zone) → blur + hairline (locked under content). This handles the "bleed under nav bar" problem cleanly and gives the screen a polished, premium feel.

Patterns A + B + C together produce the canonical premium hotel-hero experience. None of them require a third-party library on iOS 17+.

---

## SwiftUI Recipes

### Recipe A — The Anchored Stretchy Hero (the core fix)

This is the single highest-leverage change. It eliminates the white gap and the flat top edge at once.

```swift
extension View {
    /// Stretches the view from its bottom anchor when its scroll-view container
    /// is pulled down past 0. No state, no preferences — pure visualEffect.
    func stretchyHero() -> some View {
        visualEffect { effect, geometry in
            let height = geometry.size.height
            let minY = geometry.frame(in: .scrollView).minY
            let pull = max(0, minY)              // only react to overscroll
            let scale = (height + pull) / height // > 1 when pulled
            return effect.scaleEffect(
                x: scale, y: scale, anchor: .bottom
            )
        }
    }
}
```

**Usage:**
```swift
ScrollView {
    VStack(spacing: 0) {
        Image(hotel.heroImageName)
            .resizable()
            .scaledToFill()
            .frame(height: 320)
            .clipped()
            .stretchyHero()              // <-- stretch + anchor
        contentBelow
    }
}
.ignoresSafeArea(edges: .top)            // <-- bleed under nav
.toolbarBackground(.hidden, for: .navigationBar)
```

**Math:** `scale = (h + pull) / h`. At 0 pull, scale is 1.0. At 80pt pull on a 320pt hero, scale is 1.25. At 320pt pull, scale is 2.0 — the image has doubled. The bottom anchor keeps the content below the hero stationary.

**Why it works:** `visualEffect` runs every frame on the GPU compositor thread. No `@State`, no preference keys, no published values, no dirty-flag invalidation. Because the image's transform is computed from its OWN scroll-relative geometry, you do not need to track scroll offset upstream.

### Recipe B — The 3-Stop Scrim (kills the hard edge)

```swift
extension View {
    func editorialScrim(height: CGFloat = 100) -> some View {
        overlay(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color(.systemBackground).opacity(0.7), location: 0.6),
                    .init(color: Color(.systemBackground), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: height)
            .allowsHitTesting(false)
        }
    }
}
```

Apply directly to the hero:
```swift
Image(hotel.heroImageName)
    .resizable()
    .scaledToFill()
    .frame(height: 320)
    .clipped()
    .editorialScrim()           // <-- soft fade into content
    .stretchyHero()
```

**Critical:** apply the scrim BEFORE the stretchyHero modifier. The scrim is part of the visual element being stretched, so it should travel with the stretch.

### Recipe C — Three-Phase Nav Bar with `onScrollGeometryChange`

```swift
struct HotelDetailScreen: View {
    let hotel: Hotel
    private let heroHeight: CGFloat = 320
    @State private var scrollY: CGFloat = 0

    private var navBlurOpacity: Double {
        // phase 1: 0 below 60% of hero
        // phase 2: linear ramp 60% → 90%
        // phase 3: 1.0 past 90%
        let start = heroHeight * 0.6
        let end   = heroHeight * 0.9
        return Double(((scrollY - start) / (end - start)).clamped(0, 1))
    }

    private var titleVisible: Bool {
        scrollY > heroHeight - 60
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(hotel.heroImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: heroHeight)
                    .clipped()
                    .editorialScrim()
                    .stretchyHero()
                content
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(scrollBackground) // see Recipe D
        .onScrollGeometryChange(for: CGFloat.self,
            of: { geo in geo.contentOffset.y },
            action: { _, y in scrollY = y })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(hotel.name)
                    .opacity(titleVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: titleVisible)
            }
        }
        .toolbarBackground(
            navBlurOpacity > 0.05 ? .visible : .hidden,
            for: .navigationBar
        )
        .toolbarBackground(.regularMaterial, for: .navigationBar)
    }
}

private extension Comparable {
    func clamped(_ a: Self, _ b: Self) -> Self { min(max(self, a), b) }
}
```

**Timings:**
- Title fade: `.easeInOut(duration: 0.18)` — fast enough to feel instant, slow enough to register.
- Blur material: handled implicitly by SwiftUI's animation when toolbarBackground visibility flips.

### Recipe D — Backdrop Color That Fills the Overscroll (the Spotify trick)

Even with Recipe A, there are edge cases (programmatic scroll, content-shorter-than-screen) where overscroll could still expose a background. Belt-and-suspenders fix: place a same-colored view behind everything.

```swift
private var scrollBackground: some View {
    // Blends into the hero on pull-up, into the content background on pull-down.
    LinearGradient(
        colors: [hotel.accentColor.opacity(0.4), Color(.systemBackground)],
        startPoint: .top, endPoint: .bottom
    )
    .ignoresSafeArea()
}
```

If you don't have an accent color, just use `Color(.systemBackground).ignoresSafeArea()`. The white gap goes away because there is never a "white" — the page background extends infinitely.

### Recipe E — Floating Material Chrome (bonus, for completeness)

The premium pill-style back/share buttons over photography:

```swift
struct CapsuleChrome<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(10)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }
}
```

Use `.regularMaterial` not `.ultraThinMaterial` — the former adapts contrast to the underlying image; the latter can disappear over light photography.

---

## Common Motifs Across Luxury / Editorial Apps

**Anchor at bottom, always.** Of every stretch implementation reviewed, none anchored at top or center. Bottom anchor = page feels stationary, image feels alive.

**Material chrome, not solid.** `.regularMaterial` capsules over photography. Solid white circles look like web. Material says "iOS native."

**3-stop scrims, not 2-stop.** The non-linear gradient curve is what separates premium from generic. A 2-stop gradient has a perceptible midline; a 3-stop gradient hides it.

**Ken burns is optional but additive.** Hopper, Smith, and a few editorial apps layer a slow 1.0 → 1.05 zoom on the hero at rest. It compounds with the pull-down stretch and gives the screen a "the image is breathing" quality. 6–12 second cycle, ease-in-out, autoreverses.

**Blur on extreme stretch.** When stretch can exceed ~1.5x (Twitter's 6x is extreme), layer in a Gaussian blur proportional to stretch distance. This hides the per-pixel mush of photographic interpolation.

**Three-phase nav transition is a constant.** Transparent → fading blur → locked blur with hairline. Every premium app does this. The hairline at phase three is what separates "almost there" from "shipped."

**Disable bounce when in doubt.** HotelTonight ships with bounce off. It's not as luxurious, but it eliminates the entire problem class. If your brand isn't editorial, this is a legitimate path.

---

## What To Do First

For the immediate hotel listings hero fix, in priority order:

1. **Apply Recipe A (stretchyHero).** Eliminates the white gap. ~10 lines of code.
2. **Apply Recipe B (3-stop scrim).** Eliminates the hard flat edge. ~15 lines.
3. **Apply Recipe D (backdrop color).** Defense in depth against any remaining overscroll exposure. ~5 lines.
4. **Apply Recipe C (three-phase nav).** Polishes the scroll-up experience. ~30 lines.
5. **Optional: Recipe E (material chrome).** Replaces any solid-color floating buttons. ~15 lines.

The first three changes alone will move the screen from "broken" to "premium-feeling." Recipe C is what takes it from premium-feeling to indistinguishable from Airbnb. Recipe E is finishing polish.

Total surface area: under 100 lines of pure SwiftUI, no third-party dependencies, no UIKit interop, all iOS 17+ APIs.

---

## Sources

- [60fps.design — Airbnb iOS App animations](https://60fps.design/apps/airbnb)
- [nilcoalescing — Stretchy header in SwiftUI with visualEffect](https://nilcoalescing.com/blog/StretchyHeaderInSwiftUI/)
- [Brandon Baars — SwiftUI Stretchable Header with Parallax Scrolling (Medium / The Startup)](https://medium.com/swlh/swiftui-create-a-stretchable-header-with-parallax-scrolling-4a98faeeb262)
- [Sebastien Lato — How to Build Modern Parallax & Scroll Effects in SwiftUI (DEV)](https://dev.to/sebastienlato/how-to-build-modern-parallax-scroll-effects-in-swiftui-20n3)
- [Thomas Frank — Stretchy Headers in SwiftUI with visualEffect](https://medium.com/@thomasostlyng/stretchy-headers-in-swiftui-with-visualeffect-fff973568323)
- [LePips — SwiftUI parallax & stretchy background header ViewModifier (gist)](https://gist.github.com/LePips/f2ea32ee2748b6baef0e896f69f665aa)
- [Apple — toolbarBackground(_:for:) documentation](https://developer.apple.com/documentation/swiftui/view/toolbarbackground(_:for:)-7lv0f)
- [Apple WWDC23 — Beyond scroll views (session 10159)](https://developer.apple.com/videos/play/wwdc2023/10159/)
- [Apple — ScrollTargetBehavior documentation](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior)
- [codeherence — Building the Animated Twitter Profile Header](https://codeherence.medium.com/building-the-animated-twitter-profile-header-with-react-native-header-a22a2b26c109)
- [Vincent van der Meulen — Recreating Spotify's Scroll Animation (Framer X)](https://medium.com/@vincentmvdm/recreating-spotifys-scroll-animation-in-framer-x-5e116de5b716)
- [Disney Streaming Blog — Latest UX Enhancements for Disney+](https://medium.com/disney-streaming/introducing-our-latest-ux-enhancements-for-disney-f7c93a4e38cb)
- [Mobbin — HotelTonight iOS screens](https://mobbin.com/apps/hotel-tonight-ios-a2bc2cc1-3164-49f3-8e3a-4c1f11e56b9f/_/screens)
- [Mr & Mrs Smith — App](https://www.mrandmrssmith.com/app)
- [Apple HIG — Maps](https://developer.apple.com/design/human-interface-guidelines/maps)
- [SwiftUI Lab — MatchedGeometryEffect Part 1 (Hero Animations)](https://swiftui-lab.com/matchedgeometryeffect-part1/)
- [SwiftUISnippets — Adding a Scrim Gradient Overlay to Images with Swift](https://swiftuisnippets.wordpress.com/2024/07/18/adding-a-scrim-gradient-overlay-to-images-with-swift/)
- [Hacking with Swift — How to disable ScrollView clipping so contents overflow](https://www.hackingwithswift.com/quick-start/swiftui/how-to-disable-scrollview-clipping-so-contents-overflow)
- [Software Development Notes — Scroll transition effects in iOS 17](https://swdevnotes.com/swift/2024/scroll-transition-effects-in-ios-17/)
- [Peter Friese — SwiftUI Hero Animations with NavigationTransition](https://peterfriese.dev/blog/2024/hero-animation/)
