# Airbnb, Hilton, Marriott & Editorial Hospitality — Micro-Interaction Patterns

A field guide to the specific transitions, timings, and component behaviors that define premium hospitality apps on iOS, with concrete SwiftUI implementation notes for each pattern.

---

## 1. The Airbnb Search Bar — Tap-to-Expand

This is the signature Airbnb interaction and the one worth studying frame-by-frame. It's the canonical example of a "morphing" container transition that disguises a navigation push as an in-place expansion.

### What you actually see

1. Resting state: a pill at the top of the Explore tab. Roughly `343pt × 56pt`, full-width minus 16pt insets, corner radius `28pt` (perfect pill, half the height).
2. User taps the pill. The pill begins to grow — width pins to screen edges, height climbs, corner radius interpolates from `28pt` toward `12pt`.
3. As the pill grows, its internal contents (the magnifying glass + "Anywhere · Any week · Add guests" label) cross-fade out (~80ms) and a structured search panel cross-fades in (Where / When / Who segmented section, plus tabs for Stays / Experiences along the top).
4. The background tab content darkens behind a black scrim (alpha ~0.4) that fades in across the same window.
5. Resolved state: a near-full-screen sheet anchored to the top safe area. The original pill is now the title region of the sheet.

The whole thing lasts ~350-420ms. It feels like one object morphing rather than a dismiss + present sequence — that's the entire point.

### Timing & easing

- **Spring**: this is a single spring, not a chained set of curves. Closest match is `response: 0.45, dampingFraction: 0.82`. Airbnb's RN implementation uses Reanimated's `withSpring` with similar physical values. On iOS 17+ the equivalent is `.spring(.snappy)` or a custom `.spring(response: 0.45, dampingFraction: 0.82)`.
- **Cross-fade window**: pill text fades out in the first ~30% of the spring (0-130ms), panel content fades in over the next ~40% (130-300ms). They overlap minimally.
- **Scrim**: `.easeOut` over 250ms. Fades faster than the geometry resolves so the background is visually "gone" before the morph completes.
- **Haptic**: `UIImpactFeedbackGenerator(style: .light)` fires on touch-up-inside, before the animation begins. Not on completion.

### SwiftUI implementation

`matchedGeometryEffect` is the right primitive but you have to be careful — the naive implementation produces popping because the source view unmounts while the destination is still laying out. The trick is:

```swift
@Namespace private var searchNS
@State private var isExpanded = false

ZStack(alignment: .top) {
    // Always-mounted background content
    ExploreContent()

    if !isExpanded {
        SearchPill()
            .matchedGeometryEffect(id: "search", in: searchNS, properties: .frame, anchor: .top, isSource: true)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    isExpanded = true
                }
            }
    } else {
        SearchSheet(onDismiss: { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { isExpanded = false } })
            .matchedGeometryEffect(id: "search", in: searchNS, properties: .frame, anchor: .top, isSource: false)
            .transition(.asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.18).delay(0.08)),
                                    removal: .opacity.animation(.easeIn(duration: 0.12))))
    }

    if isExpanded {
        Color.black.opacity(0.4).ignoresSafeArea()
            .transition(.opacity)
            .onTapGesture { /* dismiss */ }
            .zIndex(-1)
    }
}
```

Key points:
- Use `.frame` properties only (not `.size`) so position interpolates too.
- Anchor `.top` keeps the pill pinned during expansion — without this it drifts to center mid-animation.
- The sheet content uses an `.opacity` transition with a small delay so it appears once the container is large enough to host it. Without the delay, the sheet contents inflate at small size and look squashed.
- For the dismiss, run a slightly tighter spring (higher dampingFraction). Asymmetric springs read as "more decisive on the way in, settled on the way out."

### What SwiftUI can't do here

- The exact rasterized cross-fade Airbnb does on the inner pill text (where the magnifying glass slides into the sheet header) requires a snapshot-based approach. SwiftUI's `matchedGeometryEffect` only matches geometry, not rasterized pixels. For a faithful clone you snapshot the source pill into a `UIImage`, animate it via UIKit `UIView.animate`, and remove on completion. For most production apps, the SwiftUI cross-fade is good enough and nobody notices.
- True "rubber-band" overshoot on the scrim is not free with SwiftUI's spring — you get critical damping by default. Tune `dampingFraction` below 0.7 if you want visible overshoot, but be careful: it reads as buggy on the search bar morph.

---

## 2. The Airbnb Listing Card

Every card in the search results is doing more than you think.

### Anatomy

- **Image carousel** — full-bleed at top, aspect ratio ~1:1 to ~4:3 depending on screen. Page indicators are 6pt circles, white at 70% opacity, separated by 6pt, anchored 12pt from the bottom. Active dot is white at 100%.
- **Heart icon** — top-right corner, 14pt from the edges. SF Symbol `heart` / `heart.fill`. White stroke when unfilled (over photo), red `#FF385C` (Airbnb's "Rausch" brand color) when filled.
- **Gradient overlay** — subtle linear gradient from `Color.black.opacity(0.0)` at ~60% height down to `Color.black.opacity(0.25)` at the bottom. Just enough to keep the page indicators legible against any photo.
- **Below image**: title row (location, weight `.semibold`, ~15pt), distance/dates (gray `.secondary`, ~14pt), price (weight `.semibold` + `night` in `.regular`, gray).
- **Rating** — right-aligned on the title row, star + numeric value, no review count in the card (that's on detail).

### Image carousel

It's a horizontal `TabView` with `PageTabViewStyle`. Lazy-loaded — adjacent images preload, the rest fault in on swipe. SwiftUI:

```swift
TabView(selection: $currentImageIndex) {
    ForEach(Array(listing.images.enumerated()), id: \.offset) { index, url in
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
            switch phase {
            case .empty: Color(.systemGray6).overlay(ProgressView().tint(.white))
            case .success(let img): img.resizable().scaledToFill()
            case .failure: Color(.systemGray5)
            @unknown default: Color(.systemGray5)
            }
        }
        .tag(index)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never)) // build your own dots; the default ones look mediocre
.aspectRatio(1.0, contentMode: .fit)
.clipShape(RoundedRectangle(cornerRadius: 12))
```

Page indicators are custom because the default SwiftUI ones don't render correctly over imagery (they pick up the OS tint, not white-on-photo).

### Heart-tap micro-animation

The heart bounces. Specifically:
1. On tap, the icon scales `1.0 → 1.3` over ~120ms with `.easeOut`.
2. Then springs back to `1.0` with `response: 0.4, dampingFraction: 0.55` (intentionally underdamped — it bobbles slightly).
3. Color transitions from `.white` outline to `#FF385C` fill at the 60ms mark — the swap is hidden behind the scale-up so you never see the actual SF Symbol cross-fade.
4. Light haptic at the moment of tap.

```swift
@State private var isLiked = false
@State private var heartScale: CGFloat = 1.0

Button {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.easeOut(duration: 0.12)) { heartScale = 1.3 }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { heartScale = 1.0 }
    }
    isLiked.toggle()
} label: {
    Image(systemName: isLiked ? "heart.fill" : "heart")
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(isLiked ? Color(red: 1, green: 0.22, blue: 0.36) : .white)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .scaleEffect(heartScale)
}
```

You can also stack a "burst" of small hearts that fly outward on the like — Twitter pioneered this, Airbnb doesn't actually do it on the index card, but it's table stakes if you want extra delight. Implement with a `ZStack` of 6 small hearts using `.modifier` for a custom `BurstEffect` that animates `offset` + `opacity` + `scale` across 400ms with staggered delays.

### Scroll-driven parallax

When the card is in a vertically scrolling list, its image translates at ~0.4× the scroll velocity, creating a parallax. This is done with a `GeometryReader` reading the card's frame in the global coordinate space:

```swift
GeometryReader { geo in
    let yOffset = geo.frame(in: .global).minY
    Image(...)
        .offset(y: -yOffset * 0.15) // subtle, not aggressive
        .frame(height: geo.size.height * 1.3) // overdraw so edges don't reveal
        .clipped()
}
```

Be careful with this: parallax in a `LazyVStack` is expensive because every visible card is calling `GeometryReader`, which forces layout invalidation each scroll tick. Profile it. On real devices it's fine; in the simulator it can stutter and mislead you.

### Tap-to-scale

When you tap-and-hold a card before navigating, it scales down to ~0.97 with a 150ms `.easeOut`. This is the standard `ButtonStyle` pattern:

```swift
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
```

Apply to the entire card. Combined with `matchedGeometryEffect` on the image, this sets up the hero transition into the detail view.

---

## 3. Loading & Empty States

Airbnb does not use a generic spinner. They use a shimmer skeleton that mirrors the final layout.

### Shimmer pattern

Three rectangular placeholders per card:
- The image area (full-bleed, aspect ratio matched).
- Two text lines — first ~70% width, second ~40% width.
- The shimmer itself is a diagonal gradient (45°) sliding from leading to trailing, ~1.5s loop, `.linear` repeat.

The shimmer color is `.systemGray6` base with a `.systemGray5` highlight band, ~30% width of the placeholder. On dark mode it inverts to `.systemGray5` / `.systemGray4`.

```swift
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: phase),
                    .init(color: .white.opacity(0.5), location: phase + 0.15),
                    .init(color: .clear, location: phase + 0.3)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
        )
        .mask(content)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}
```

`.plusLighter` blend mode is what makes it actually look like reflected light rather than a painted gradient.

### Skeleton placement

Airbnb shows ~3 skeleton cards in the search results before the first real card resolves, then real cards fade in as they arrive (one by one, not in a batch). Each card has its own ~200ms `.easeIn` fade. This sequenced appearance is critical — a synchronized batch fade reads as "the network was slow." Sequenced fades read as "results are streaming in."

### Empty states

For zero-results: an illustration (Airbnb uses their "Bélo" character mark in soft gray), 24pt of vertical breathing room above and below, a friendly headline (`28pt, .semibold`, near-black), a one-line subhead (`16pt, .regular, .secondary`), and a primary CTA pill.

The illustration appears with a slight scale-in: `0.92 → 1.0` over 350ms with `.spring(response: 0.5, dampingFraction: 0.75)`. Subhead and CTA fade in 100ms after the illustration with `.easeOut`. Total entrance ~500ms.

### Branded loading splash

When the app cold-launches, Airbnb shows a brief Bélo logo that pulses (scale `1.0 ↔ 1.05` with 800ms `.easeInOut.repeatForever(autoreverses: true)`). This stays up for a max ~600ms in practice — usually the home is already painted and the splash is masked by a cross-fade.

---

## 4. Hilton Honors

Hilton's app is more "corporate hospitality" than "marketplace" — the design language reflects that. Less photo-forward, more chrome, more booking-flow optimization.

### Navigation transitions

Standard `UINavigationController` push/pop with default iOS curves (~350ms `easeInOut`). They've made no attempt to customize these — and that's fine, because their brand authority comes from typography (Loews-grade serif headings) and color discipline (deep navy `#002F61`, gold accents `#A6914B`).

### Hotel detail card

Top section is a hero photo carousel (similar to Airbnb but at a wider 16:9 aspect ratio, less square). Below is a structured table:
- Hotel name (24pt, weight `.bold`, navy)
- Star rating + review count
- Address (one line, tap to open Maps)
- Amenity row of icons (pool, gym, wifi, parking — flat icons, no fill, gray)
- Room type cards stacked vertically with price-per-night anchored right

The amenity icons are interesting: each is ~24pt SF Symbol-style but custom-drawn, with a label below in 11pt all-caps tracking. They look more like infographic chips than "icons." This is the Hilton signature — they treat amenities as data, not decoration.

### Image-led layouts

Hilton does use full-bleed photography for property heroes, but they over-darken the bottom 40% with a gradient (alpha 0 → 0.65) so white text reads cleanly over any photo. This is a defensive choice: their photos come from thousands of properties of varying quality, so they can't trust the imagery.

### Premium flourishes

- A "Digital Key" interaction where the room number reveals via a crossfade + key icon scale-in. Spring `response: 0.5, dampingFraction: 0.7`. Haptic notification (success).
- Bottom-sheet booking summary that pulls up with a slight rubber-band on overscroll. Custom gesture handling — UIKit-based, not SwiftUI's standard sheet.

---

## 5. Marriott Bonvoy

Marriott Bonvoy is the most brand-forward of the three. Their app showcases that they own ~30 brands (Ritz-Carlton, St. Regis, W, Moxy, etc.) and the design has to flex across all of them.

### Hotel rows

Wider than tall (16:9 hero photo), brand mark in the top-left corner of the image as a small white badge (the Ritz-Carlton lion, the W "letter," etc.), gold star count, hotel name beneath in a sans-serif (typically Source Sans Pro or similar), city + country in `.secondary`.

Notable: the brand badge stays consistent across all rows but changes color/glyph per property. This is a strong visual signal — you scan a list and immediately read which properties are which tier.

### Color treatment

The Bonvoy brand color is a deep Bonvoy "Marriott Gold" `#9B7B3F` plus near-black `#1C1C1C`. Backgrounds are warm off-whites (`#F8F6F2` rather than neutral `#fafafa`). This creates a hospitality-warm feeling vs. Airbnb's cooler, more tech-startup palette.

### Brand prominence in lists

Each card has a thin gold underline (1px, `#9B7B3F`) below the title separator. It's nearly subliminal but it ties every card back to the master brand. Worth stealing for any hospitality app: a single consistent brand-color hairline element across all content.

### Points & status

The Bonvoy header surfaces tier (Silver / Gold / Platinum / Titanium / Ambassador) with a tier-specific color band at the top of the home screen. This is animated with a slow gradient shimmer (3-4s loop) on Titanium and Ambassador only — the higher tiers literally shimmer, the lower tiers don't. Subtle, expensive-feeling.

---

## 6. Booking.com Mobile — The Information-Density Counterpoint

Booking is the anti-Airbnb. Where Airbnb hides chrome and trusts photography, Booking front-loads data: price, savings tag, "Only 2 rooms left at this price!", review badge, location, distance from center, breakfast included, free cancellation. A single card might have 8+ distinct text elements.

### Trade-offs

- **Booking optimizes for transactional intent.** You're price-shopping with intent to book. Density is conversion-driver.
- **Airbnb optimizes for inspirational browsing.** You're looking for "vibe" first. Density is conversion-killer.
- For a hospitality app like ResortPass — where users are deciding between day passes at properties they may not be familiar with — you probably want a hybrid: photo-forward like Airbnb, with one "trust" line of structured data (price + 2-3 amenities) per card. Don't go full Booking. Don't go full Airbnb. Steal Marriott's brand-hairline trick.

### Booking's animation language

Almost none. Standard iOS push transitions. Their cards do not animate on appearance. Their loading state is a generic spinner. This is a deliberate choice — animation feels like delay when you're trying to book a hotel before someone else does. **For a booking flow, polish through restraint.** For a discovery flow, polish through motion.

---

## 7. Common Premium-App Patterns

### Bottom sheets for filters

The standard for filter UIs across all of these apps. iOS 16+ gives us `.presentationDetents([.medium, .large])` natively:

```swift
.sheet(isPresented: $showFilters) {
    FilterSheet()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationCornerRadius(16)
}
```

`presentationBackgroundInteraction(.enabled(upThrough: .medium))` is the key — it lets users tap content beneath the half-sheet without dismissing it. This is what makes filter UIs feel additive rather than modal.

Airbnb's filter sheet specifically uses three detents (small / medium / large) and animates between them with `response: 0.4, dampingFraction: 0.85`. SwiftUI doesn't expose three detents directly but you can use `.height(200)`, `.medium`, `.large`.

### Pull-to-refresh

Airbnb has a custom pull-to-refresh that uses their Bélo logo, which scales up `0.6 → 1.0` as you pull, and rotates while loading. iOS 15+ has `.refreshable { }` but it gives you the system spinner. To customize you have to drop down to a `UIScrollView` wrapped in `UIViewRepresentable`, observe contentOffset, and overlay your own animation. Worth it for the brand moment, not worth it for everything else.

### Long-press preview cards

iOS 13+ context menus do this for free with `.contextMenu(menuItems:preview:)`:

```swift
.contextMenu {
    Button("Save", systemImage: "heart") { /* ... */ }
    Button("Share", systemImage: "square.and.arrow.up") { /* ... */ }
} preview: {
    HotelDetailPreview(hotel: hotel) // larger hero card
        .frame(width: 320, height: 420)
}
```

The system handles the spring-up, the scale, the haptic, and the dismiss. You do nothing. This is one of the cheapest "premium" moments you can ship.

### Scroll-driven nav bar reveal

The pattern where the nav bar is invisible while content is scrolled near the top, then fades in as a translucent bar with the page title once you scroll past a threshold. Airbnb does this on every property detail.

```swift
@State private var scrollY: CGFloat = 0
var navOpacity: Double { min(1, max(0, Double((scrollY - 100) / 60))) }

ScrollView {
    HotelHero()
    HotelDetails()
}
.background(GeometryReader { proxy in
    Color.clear.preference(key: ScrollOffsetKey.self,
                           value: proxy.frame(in: .named("scroll")).minY)
})
.coordinateSpace(name: "scroll")
.onPreferenceChange(ScrollOffsetKey.self) { scrollY = -$0 }
.overlay(alignment: .top) {
    NavBar()
        .background(.ultraThinMaterial.opacity(navOpacity))
        .opacity(navOpacity)
}
```

Use `.ultraThinMaterial` — it's the iOS-native blur and matches user expectations. Tune the threshold (`100pt` here) and the fade range (`60pt`) to your hero height.

### Image fade-in + lazy load

`AsyncImage` with a `Transaction(animation: .easeInOut(duration: 0.25))` gives you the standard iOS image fade. For caching across scroll, swap `AsyncImage` for `Kingfisher` or `Nuke` — the SwiftUI one is correct but doesn't cache decoded images aggressively enough for fast-scrolling lists.

### Heart-burst micro-animation

Covered above in §2. The pattern generalizes: any "primary action" button (book, save, like, follow) benefits from a 120ms scale-up + 400ms underdamped spring back. Don't overdo it — the bobble should be subtle. If users see the bobble consciously, you've gone too far.

---

## 8. SwiftUI vs. UIKit — What You Actually Need

| Pattern | SwiftUI native? | Notes |
|---|---|---|
| Search bar morph | Yes (matchedGeometryEffect) | Snapshot trick needed for pixel-perfect inner cross-fade |
| Image carousel + dots | Yes (TabView) | Build dots manually for white-on-photo legibility |
| Heart bounce | Yes | Trivial |
| Card parallax | Yes (GeometryReader) | Profile on real devices; can stutter in lists |
| Bottom sheet (3 detents) | Yes (iOS 16+) | `.presentationDetents` |
| Long-press preview | Yes | `.contextMenu(preview:)` |
| Scroll-driven nav fade | Yes | Preference key dance |
| Custom pull-to-refresh | No | UIViewRepresentable required |
| Hero transition (image grows) | Mostly yes (matchedGeometryEffect) | Tricky during navigation push; works cleanly with `.fullScreenCover` |
| Shared-element across NavigationStack | Partial | iOS 18 zoom transition (`.navigationTransition(.zoom)`) ships this natively for NavigationLink — use it |
| Rubber-band overscroll on sheet | No | Custom UIKit gesture |

### iOS 18 — `.navigationTransition(.zoom)`

If you're targeting iOS 18+, the built-in zoom transition (introduced for App Store-style detail navigations) handles the Airbnb-style card-to-detail morph natively:

```swift
NavigationLink {
    HotelDetailView(hotel: hotel)
        .navigationTransition(.zoom(sourceID: hotel.id, in: namespace))
} label: {
    HotelCard(hotel: hotel)
        .matchedTransitionSource(id: hotel.id, in: namespace)
}
```

This is a meaningful upgrade. Pre-iOS-18 you had to fake it with `matchedGeometryEffect` + `fullScreenCover` and it never quite landed. Now it's a one-liner. If your minimum target is 17, fall back to the manual approach for that audience.

---

## 9. Editorial / Luxury Hospitality (Mr & Mrs Smith, One Hotels)

These apps treat hospitality like a magazine. Less utility, more curation.

### Mr & Mrs Smith

- **Layout:** wide-margin centered prose (`360pt` content width on a `393pt` iPhone screen). Generous left/right insets.
- **Typography:** custom display serif for headings (something close to GT Sectra or Tiempos), 32-40pt with `letter-spacing: -0.02em`. Body is a clean sans (Founders Grotesk-style) at 17pt with `line-height: 1.6`.
- **Image treatment:** full-bleed, no rounded corners on the hero, no scrim, photo carries the page. They trust their photography. Captions appear as small italic serif beneath in a darker gray.
- **No chrome:** no nav bar visible until you scroll. No tab bar most of the time. The status bar disappears on hero pages. The interface gets out of the way.
- **Detail cards:** rather than data tables (rooms, amenities, location), they're written paragraphs — "The hotel sits on 200 acres of olive grove, with 14 suites housed in restored Tuscan farmhouses." Scannable still, but feels editorial.

### One Hotels

- **Color:** warm earth tones, sustainable-design adjacent (sage greens, terracotta, off-white).
- **Photography:** human-scale (people in spaces) rather than empty rooms. Strong creative direction.
- **Animations:** very few. A single slow fade on page load (~600ms `.easeOut`). Otherwise the app feels still, like a print magazine.

### Key takeaway for ResortPass

The editorial style only works if you have the photography to back it up. ResortPass deals with hotel pool/spa photography of varying quality. You probably want to lean Airbnb-flat with editorial accents — generous margins, a serif for property names if you can find one that doesn't look out of place, but defensive scrims and structured data for the cards.

---

## 10. Reference Timing Values

A summary table of every observed timing across these apps. Use these as defaults; tune from here.

| Interaction | Curve | Duration / Spring |
|---|---|---|
| Search bar tap-to-expand (Airbnb) | spring | response 0.45, damping 0.82 |
| Search bar dismiss | spring | response 0.42, damping 0.86 |
| Pill-text cross-fade out | easeOut | 130ms |
| Sheet content fade-in (delayed) | easeOut | 180ms, 80ms delay |
| Scrim fade-in | easeOut | 250ms |
| Heart scale-up | easeOut | 120ms |
| Heart spring-back | spring | response 0.4, damping 0.55 |
| Card press-down | easeOut | 150ms (scale 0.97) |
| Image fade-in (lazy load) | easeInOut | 200-250ms |
| Page indicator transition | easeInOut | 200ms |
| Shimmer cycle | linear, repeatForever | 1500ms |
| Skeleton-to-content fade per card | easeIn | 200ms (sequenced, not batched) |
| Empty-state illustration scale-in | spring | response 0.5, damping 0.75 |
| Empty-state subhead/CTA fade | easeOut | 250ms, 100ms delay after illustration |
| Splash logo pulse | easeInOut, repeatForever, autoreverses | 800ms |
| Filter sheet detent transition | spring | response 0.4, damping 0.85 |
| Nav bar reveal threshold | linear | over 60pt of scroll, starting at 100pt |
| Nav bar background blur | n/a | `.ultraThinMaterial` |
| Long-press context menu | system | ~400ms (iOS-managed) |
| Bonvoy tier shimmer (Titanium/Ambassador) | linear, repeatForever | 3500ms |
| Hilton digital key reveal | spring | response 0.5, damping 0.7, success haptic |
| iOS 18 `.navigationTransition(.zoom)` | system spring | ~450ms total |

### Haptic timing rules

- Light impact (`UIImpactFeedbackGenerator(style: .light)`) — fired on touch-up-inside, before the visual animation begins. Heart, search bar tap, filter chip select.
- Medium impact — on a state commitment that has weight (saving a hotel to a list, applying filters).
- Notification haptic (`.success`) — on a task completion (booking confirmed, digital key issued).
- Selection feedback (`UISelectionFeedbackGenerator`) — on tab switches, segmented control changes, page-indicator changes during a swipe (Airbnb does this on each carousel page).

Never fire haptics on view appear, on scroll, or on animation completion. Only on user-initiated, intentional actions.

---

## Recommendations for ResortPass

Picking the elements worth stealing for a day-pass marketplace:

1. **Steal:** Airbnb's search bar tap-to-expand pattern. It's the strongest "this app is premium" moment you can ship in a single interaction. SwiftUI handles it with `matchedGeometryEffect` + a single spring.
2. **Steal:** Airbnb's image carousel + heart bounce. Table stakes.
3. **Steal:** Marriott's brand-color hairline under titles. Quiet but consistently present.
4. **Steal:** Sequenced skeleton-to-content fades (not batched). One of the cheapest perceived-quality wins.
5. **Steal:** iOS 18 `.navigationTransition(.zoom)` if you can target 18+. Otherwise the manual `matchedGeometryEffect` hero.
6. **Skip:** Custom pull-to-refresh. The system one is fine. Spend the engineering time elsewhere.
7. **Skip:** The full editorial typography treatment. You don't have the photography curation to back it. Lean structured-cards with one editorial flourish (a serif for property name) and stop there.
8. **Match Airbnb's restraint, not Booking's density.** A day-pass user is browsing for vibe + value, closer to Airbnb's mode than Booking's.
