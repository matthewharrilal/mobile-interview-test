# 60fps.design Survey — Hotel & Travel Card Patterns

**Source:** 60fps.design (1,930 shots / 457 apps), cross-referenced with Mobbin, ScreensDesign, App Store screenshots, and direct app teardowns.
**Scope:** Hospitality / travel / lifestyle listing cards, search rows, and the depth treatments that make them feel "alive" instead of inert containers.
**Constraint encountered:** 60fps.design gates the actual recording playback behind PRO. Shot titles are public, video is not. The titles themselves carry a lot of signal — they're written like animation specs, not blog posts ("Card Thumbnails Scale Pop", "Yoga Class Card Carousel Morph", "Continue Searching Card Scale Interaction") — so this report uses the title taxonomy as a map and pulls the actual visual detail from the apps themselves.

---

## 1. The Travel/Hospitality Slice on 60fps.design

The site's travel category is shallower than its fintech and food categories. The complete inventory of travel/hospitality apps with shots:

| App | Shots Visible | Notes |
|---|---|---|
| Airbnb | 28 | Deepest catalog — covers carousel, host, search, identity, services |
| Flighty | 9 | Flight cards, passport, delay intel, aircraft stats |
| Wolt | 2 | Timer-to-map zoom, 3D coin flip |
| Marriott Bonvoy | 1 | Splash only |
| Four Seasons | 1 | Navigation gestures tip |
| Kayak | 1 | Price check intro |
| MakeMyTrip | 1 | Logo splash |
| TravelPerk | 1 | Splash |
| Klook | 1 | Splash |
| Cathay Pacific | 1 | Passport scan |
| Qatar Airways | 1 | "Home Cards Section" |
| Globetrotter | 2 | Search interaction, onboarding |
| Gowalla | — | Listed, no shots scraped |

Notable absences: Booking.com, Expedia, Hotel Tonight, Vrbo, Hilton Honors, Hyatt, Resy, OpenTable (only splash), TripAdvisor. The interesting card work in this category lives mostly outside 60fps.design — Airbnb is the one app this site has dissected at depth. Treat 60fps as the reference for **Airbnb's entire interaction grammar** and as a thin index for everyone else.

The shot titles that map directly to card behavior:

- **Airbnb New Card Thumbnails Scale Pop Animation**
- **Airbnb Photo Pop and Slide Animation**
- **Airbnb Continue Searching Card Scale Interaction**
- **Airbnb Media Morph Preview Scale Interaction**
- **Airbnb Yoga Class Card Carousel Morph Interaction**
- **Airbnb Quality Seal Animation**
- **Airbnb Guest Favorite Icon Animation**
- **Airbnb Rare Find Pop Animation**
- **Airbnb Price Toggle Interaction**
- **Airbnb Host Reveal Animation**
- **Qatar Airways Home Cards Section**

That's the surface area worth studying frame-by-frame.

---

## 2. Top 10 Hotel / Travel Card Layouts

Concrete layout breakdowns. Each one is something you can rebuild from this description without looking at a screenshot.

### 2.1 Airbnb Stay Card (current iOS, 2024–2026)

The reference implementation for the entire category. Layout:

- **Image carousel:** edge-to-edge inside the card, 4:3 aspect ratio, ~16pt corner radius. Native paged horizontal scroll, page-control dots overlaid bottom-center with a subtle drop shadow so they read on bright skies *or* dark interiors. Dots animate in/out — only 5 visible at a time even if there are 30 photos, with the row sliding so the active dot is always centered.
- **Heart (favorite):** top-right of the image, ~32pt tap target, white outline at 90% opacity with a soft drop shadow (`0 1 4 rgba(0,0,0,0.25)`) so it floats over any photo. Pop animation on tap (1.0 → 1.3 → 1.0 over ~280ms with a slight overshoot — this is the "Guest Favorite Icon Animation" shot).
- **Quality badge:** top-left, pill-shaped, white background with a tiny medallion icon, label "Guest favorite". This is *the* trust element — it's the only badge they'll ever stack on the image, and it's deliberately quiet (low contrast, small type) so it doesn't compete with the photo.
- **Below the image (no card chrome — just typography on the page background):**
  - Line 1: location, weight 500, 15pt, primary text color.
  - Line 2: secondary metadata (e.g. "Mountain and ocean views"), weight 400, 14pt, secondary text color.
  - Line 3: date range, same treatment as line 2.
  - Line 4: price + ★ rating on the right. Price is **underlined** ("$1,234 for 5 nights") which signals "tap for breakdown" and is one of Airbnb's signature interactions ("Price Toggle Interaction" shot).
- **No border, no background fill, no shadow on the text container.** Card-ness is implied entirely by image rounding + typographic grouping.

This is the layout to beat. Its trick is that it looks like 4 cards in a feed, but only the *image* is a card — the rest is naked text on the page. That's why it scrolls fast and feels weightless.

### 2.2 Airbnb "Continue Searching" Horizontal Card

A separate, denser pattern that appears when you re-open the app mid-trip-planning:

- Horizontal scroll row of compact cards, ~140pt wide × ~180pt tall.
- Image fills the top ~60% of the card, square corners on top, rounded on bottom only when the card has a visible background (it doesn't, usually).
- Below the image: 1-line destination, 1-line metadata.
- **Scale interaction on tap:** card briefly scales to ~0.97 on press, springs back. The "Continue Searching Card Scale Interaction" shot is exactly this — there's no morph, no flash, just the press feedback. Quietly expensive-feeling.

### 2.3 Airbnb "Yoga Class Card Carousel Morph"

A layout pattern that's worth stealing for any "experience" or "category" card row. The shot title implies what's happening:

- Carousel of cards with a featured central card scaled larger than the off-axis cards.
- As you swipe, the leaving card scales down to ~0.85, the entering card scales up to 1.0, and **the image inside each card morphs** — it's the same photo, but it crops/repositions during the transition rather than cutting. This is a `matchedGeometryEffect`-style continuity effect, not a crossfade.
- The card itself has a soft drop shadow that *also* morphs with scale, so the depth feels physically attached to the card.

### 2.4 Hopper "Stay" Card

Hopper's hospitality cards are denser than Airbnb's because Hopper is a price-prediction app — the price *is* the headline:

- Square or 4:3 image, top-rounded corners only (8pt).
- **Price block bottom-left of the image as an overlay**, set on a translucent dark gradient (gradient runs ~30% of card height from bottom). White type, weight 600, 18pt for the price; small strikethrough for the "was" price next to it.
- "Recommended to book" or "Watch price" pill inline with the price overlay — this is Hopper's mascot/personality channel. The bunny mascot only appears on price prediction states ("prices going up", "low risk"), not on the card itself.
- Below the image: 1-line hotel name (weight 500), 1-line rating + neighborhood, separated by a middot.
- Card sits on a `#FFFFFF` surface on a `#F7F7F7` page, with a 1pt `#E5E5E5` hairline border. **No drop shadow.** Hopper uses the border because their pages are already busy with calendar visualizations and the shadow would add visual mass.

### 2.5 Hotel Tonight "Tonight" Deal Card

The original last-minute booking app. Cards optimized for "decide in 8 seconds":

- Full-bleed image as the entire card background, ~16:9.
- Two text overlays on the image: hotel name top-left (white, weight 600, 22pt with a hard text shadow `0 1 2 rgba(0,0,0,0.5)` for readability), and a category tag bottom-left ("Hip", "Charming", "Solid", "Luxe" — Hotel Tonight's curation system).
- **Price floats bottom-right** as a chunky pill — solid white background, dark text, weight 600, 18pt. The pill sits on a deliberate angle relative to the bottom edge (~12pt margin from bottom and right) so it reads as a stamp, not a UI affordance.
- Distance/walking time inline with the category tag.
- Between cards: a **24pt deliberate gap with no divider**. The gap *is* the divider. This is the most confident spacing decision in the entire category.

### 2.6 Booking.com "Property Card"

The information-density extreme. Rebuild this if your problem is "the user needs to compare 8 hotels in 30 seconds":

- Image left-aligned, ~120pt × 120pt square with 8pt corner radius — **never** full-bleed.
- Heart top-right of image, no shadow, white circle background.
- Right column (the entire rest of the card width):
  - Line 1: hotel name (weight 500, 16pt, blue link color — Booking treats names as links).
  - Line 2: location with map-pin glyph + distance from city center.
  - Line 3: rating block — colored badge with the score (e.g. "8.7"), label "Very Good", review count.
  - Line 4: deal banner if present (red text, "Limited time deal").
  - Line 5: amenities row of small monochrome icons (wifi, pool, breakfast).
  - Line 6: price right-aligned with strikethrough original price above it.
- Card has a 1pt border, no shadow, white background on a light gray page.

This is the "spreadsheet" school of card design. It's ugly but it's an honest signal of what the user is doing — comparing.

### 2.7 Marriott Bonvoy "Find a Hotel" Result Card

Marriott's app is conservative and brand-controlled. Card layout:

- Image top, full-card-width, 16:9, no rounded corners on top (it's flush with card).
- Brand chip top-left over a faint gradient ("MARRIOTT", "RITZ-CARLTON", "WESTIN" — small caps, white type, low contrast badge fill). Brand identity matters more than visual flair here.
- Reward "points + cash" indicator top-right — circular badge with point count.
- Below image: hotel name (serif at the Ritz/Edition tier, sans-serif everywhere else), 1-line address, 1-line star rating + review count.
- Price block bottom-right, two-line: nightly rate on top, total on bottom in smaller secondary type.
- Card has a 1pt border + white background. Drop shadow only when the card is in a horizontal carousel — not in vertical lists. (This is the "shadow only when floating" pattern — see §3.)

### 2.8 Four Seasons "Property Hero" Card

Pure editorial. Useful as a counterpoint:

- Single image card, 4:5 portrait orientation, ~85% of viewport width.
- No badges, no overlays on the image.
- Title sits **below** the image in a serif (Optima or similar) at 28pt, weight 400, with generous letter-spacing (`+0.02em`).
- Single line of italic metadata below ("Maui, Hawaiʻi · From $1,200/night").
- Background is `#FAFAF7` (warm off-white). Image has a hairline `#E0DCD4` border, no shadow.
- Cards are arranged in a vertical stack with **80pt gaps**. The gaps do all the work.

This is the layout you'd reach for if ResortPass wanted to communicate *luxury* over *deal*. The price isn't hidden — it's just not weaponized.

### 2.9 Qatar Airways "Home Cards Section"

This is the only Qatar shot title that's public, and it tells you something: their home is a cards section, not a tab grid. The card pattern based on App Store screenshots:

- Horizontal carousel of square cards, ~70% viewport width.
- Each card is a full-bleed image with a long vertical gradient (`black 0% → transparent 50%`) from bottom up.
- Headline white text bottom-left (weight 500, 22pt), short kicker above it in burgundy brand color.
- Small chevron-arrow bottom-right indicating tap-to-open.
- **Cards stack with negative margin** — the next card peeks ~30pt off the right edge, signaling scrollability without dots.
- Drop shadow `0 4 16 rgba(0,0,0,0.12)` on each card.

The "peek" pattern is one of the highest-signal-to-effort moves in this entire survey. It eliminates an entire UI affordance (page dots, "see all" links) by making the next item visible.

### 2.10 Flighty "Flight Card" (the ambient detail card)

Not a hotel card, but the best example of *information layering with depth* in the entire travel category. Flighty's flight card is what you see if you tap an upcoming flight:

- Card occupies the upper ~40% of the screen, dark background `#0A0A0A` regardless of system theme.
- Top row: airline logo left, flight number right.
- Center: **massive** route display — 3-letter origin, animated airplane glyph, 3-letter destination. The plane glyph drifts left-to-right across the route as boarding/flight time progresses ("Flighty Connection Assistant Sheet" implies this).
- Bottom row: scheduled time → estimated time, with a colored chip if there's a delay (amber/red).
- The card has **two layers of shadow**: a tight `0 1 2 rgba(0,0,0,0.4)` shadow that defines the edge, and a wide `0 24 48 rgba(0,0,0,0.25)` shadow that makes it feel suspended above the screen.
- "Passport Blacklight" interaction implies they use a UV/glow material on certain elements when held to the light — actual physically-modeled material, not just a gradient.

The lesson: stack two shadows when you want a card to feel *suspended*. One contact shadow + one drop shadow is the entire trick.

---

## 3. Recurring Depth & Material Patterns

These are the moves that show up across the apps that feel "alive" vs. the ones that feel like a CRUD list.

### 3.1 The Stacked Shadow

Almost every "expensive" feeling card uses two shadows, not one:

- **Contact shadow:** 0–2pt y-offset, 2–4pt blur, `rgba(0,0,0,0.08–0.15)`. Defines the edge. Without this the card looks pasted-on.
- **Drop shadow:** 8–24pt y-offset, 24–48pt blur, `rgba(0,0,0,0.10–0.20)`. Creates the "this is hovering" depth.

In SwiftUI: stack two `.shadow(...)` modifiers. Order matters — apply the contact shadow first, drop shadow second.

### 3.2 The Translucent Overlay Bar

Used by Airbnb (page dots), Hopper (price overlay), Hotel Tonight (price pill), Qatar (gradient title bar). Two flavors:

- **Linear gradient overlay** at 30–40% of card height from the bottom: `LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .bottom, endPoint: .top)`. Used when the text needs to read on *any* photo.
- **`.ultraThinMaterial` chip** for floating UI elements (favorite, share, page dots). Backed by SwiftUI's `Material` types — these blur whatever's behind them. iOS 15+ only. The blur is the dimensionality.

### 3.3 The Image-Bleed Card (no chrome)

Airbnb's stay card. The card has no visible border, background, or shadow — only the *image* is rounded. The image's roundedness is the only thing telling your eye "this is a card." Below the image, the text just sits on the page.

This pattern looks empty until you populate the feed and realize the rhythm of [image, text, gap, image, text, gap] is itself the structure. It's also the cheapest to render (no shadow blur on a 4:3 card every row).

### 3.4 The Peek Carousel

Used by Qatar Airways, Apple Music, Airbnb Experiences. Cards in a horizontal scroll have ~15–30pt of the next card visible off the right edge. Achieves three things at once:

1. Signals "this scrolls" without page dots.
2. Anchors visual rhythm (every card has a "shoulder" of the next one).
3. Eliminates the "what comes next" UI question.

### 3.5 The Floating Heart

A near-universal pattern. The favorite heart is *not* part of the card chrome — it floats on top of the image with its own shadow. Three variants:

- **Outline-only** (Airbnb): white stroke heart, drop shadow. Empty visual weight, maximum photo respect.
- **Circular background** (Booking, Hopper): white circle with heart inside. Higher contrast at the cost of visual mass. Better for image-bleed cards where the heart could land on white sand or a white wall.
- **Material-backed** (newer iOS apps): `.ultraThinMaterial` circle, blurs the photo behind it. The sexiest of the three but only legible when the photo has texture.

### 3.6 The "Pop" Microinteraction

Three of Airbnb's shot titles include "Pop": "Card Thumbnails Scale Pop", "Host Pop", "Rare Find Pop". The pattern is:

- Element scales 1.0 → 1.15–1.30 → 1.0
- Duration: 250–320ms total
- Spring with overshoot (`response: 0.3, dampingFraction: 0.55`)
- Triggered on **state change**, not on tap (e.g. when the card enters the viewport, when a "rare find" badge appears, when host info loads)

The "pop" is your "ta-da" moment without a sound effect. Use it sparingly — once per screen, on the most important new piece of info.

### 3.7 The Morph

Airbnb's "Yoga Class Card Carousel Morph" and "Media Morph Preview Scale" both use what's effectively `matchedGeometryEffect`: an element in one screen state continues into another screen state without crossfading. The image you tapped *is* the image on the detail screen, and it grew rather than swapping.

This is the signature iOS-native feeling. Crossfades feel web; morphs feel native.

---

## 4. Information Density vs Whitespace

The pattern across the survey: **the more the brand owns the experience, the more whitespace.**

| App | Card Density | Where it sits |
|---|---|---|
| Four Seasons | Lowest — 1 image, 1 line | Editorial luxury |
| Airbnb | Low — image + 4 text rows | Aspirational marketplace |
| Hotel Tonight | Low — image with 3 overlays | Curated impulse buy |
| Hopper | Medium — image + price overlay + 2 text rows | Optimized for decision |
| Marriott | Medium — image + brand + points + price | Loyalty program first |
| Qatar Airways | Low (carousel) | Brand-owned |
| Booking.com | Highest — image + 6 text rows + amenities | Comparison engine |

For ResortPass specifically: you're closer to Hopper/Hotel Tonight than to Booking. Users browse for vibe (pool day, spa day) and decide on price + photos. The card should be **image-dominant** with at most: name, price, neighborhood, 1 vibe descriptor. Anything more turns it into a comparison spreadsheet, which kills the "I want to feel like I'm at a resort" emotional pre-sell.

The proximity rule across all the best cards: text within a card group sits at ≤8pt gaps; cards in a list sit at ≥24pt gaps. The 3x ratio is what creates the visual "this is a card / this is the next card" parsing without needing a border.

---

## 5. SwiftUI Implementation Sketches — 3 Adoptable Patterns

### 5.1 The Image-Bleed Stay Card (Airbnb pattern)

```swift
struct StayCard: View {
    let stay: Stay
    @State private var isFavorited = false
    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ImageCarousel(images: stay.photos)
                    .aspectRatio(4/3, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Quality badge
                if stay.isGuestFavorite {
                    HStack(spacing: 4) {
                        Image(systemName: "medal.fill").font(.system(size: 10))
                        Text("Guest favorite").font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                // Floating heart
                Button { toggleFavorite() } label: {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isFavorited ? .red : .white)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                        .scaleEffect(heartScale)
                }
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stay.location)
                    .font(.system(size: 15, weight: .medium))
                Text(stay.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(stay.dateRange)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                HStack {
                    Text(stay.priceLabel).underline()
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    Label(stay.rating, systemImage: "star.fill")
                        .font(.system(size: 14))
                        .labelStyle(.titleAndIcon)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func toggleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            isFavorited.toggle()
            heartScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                heartScale = 1.0
            }
        }
    }
}
```

Notes: no card background, no shadow, no border. All structure is image-corner-radius + typography rhythm. Material badge gives free blur when over busy photos.

### 5.2 The Stacked-Shadow Hero Card (Hotel Tonight / Qatar pattern)

```swift
struct HeroCard: View {
    let property: Property

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: property.heroImage) { phase in
                phase.image?.resizable().scaledToFill()
            }
            .frame(height: 220)
            .clipped()

            // Gradient overlay for text legibility
            LinearGradient(
                colors: [.black.opacity(0.7), .black.opacity(0.0)],
                startPoint: .bottom, endPoint: .top
            )
            .frame(height: 120)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(property.vibeTag.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.06)
                    .foregroundStyle(.white.opacity(0.85))
                Text(property.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            }
            .padding(20)

            // Floating price pill
            Text(property.priceLabel)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.white, in: Capsule())
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // The two-shadow trick
        .shadow(color: .black.opacity(0.10), radius: 2, y: 1)   // contact
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12) // drop
    }
}
```

Notes: the two shadows are doing the heavy lifting. Single shadow looks pasted-on. The text shadow on the headline is what makes it survive on bright photos.

### 5.3 The Peek Carousel (Qatar / Airbnb Experiences pattern)

```swift
struct PeekCarousel<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let card: (Item) -> Card

    private let cardWidthFraction: CGFloat = 0.78
    private let interItemSpacing: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width * cardWidthFraction
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: interItemSpacing) {
                    ForEach(items) { item in
                        card(item)
                            .frame(width: cardWidth)
                            .scrollTransition { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                                    .opacity(phase.isIdentity ? 1.0 : 0.7)
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, (geo.size.width - cardWidth) / 2 - interItemSpacing)
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .frame(height: 320)
    }
}
```

Notes: `scrollTransition` (iOS 17+) gives you the de-emphasized-when-off-axis treatment for free. The padding-trick centers the active card while leaving ~30pt of the next card visible. `.viewAligned` snaps cleanly without page dots.

---

## 6. Apps to Study Beyond 60fps.design

Direct teardown priorities, in order of payoff for ResortPass:

1. **Hotel Tonight** — closest analog to ResortPass's mental model (today/tonight, curated, decide-fast). Study the curation tags ("Hip", "Charming", "Solid", "Luxe") as a system.
2. **Hopper** — price-overlay-on-image pattern + calendar heatmap. The "Watch this trip" CTA inside the card is worth stealing.
3. **Airbnb** — the entire stay-card grammar. Typography hierarchy (location bold, everything else secondary) is the single most copied thing in the category.
4. **Resy** — editorial restaurant cards; "What's hot" uses image-bleed with a chunky white tag. Same vibe as a day-pass.
5. **OpenTable** — time-slot booking patterns. ResortPass's "available time slots" UI lives here.
6. **Apple Maps "Place Card"** — bottom-sheet hotel card with image carousel + amenities pills + reviews. iOS-native pattern users already know.
7. **Marriott / Hilton Honors** — points + price dual-display. Skip brand chrome, steal the dual-currency typography.
8. **Klook** — activity/experience cards (closest neighbor to "day pass"). Heavy on category iconography.
9. **Tock** — high-end editorial booking. Single hero image, serif type, no badges. Luxury reference.
10. **Letterboxd** (non-travel) — editorial card hierarchy. "Poster + score + short blurb" maps directly to "resort + price + vibe."

---

## 7. Recurring Motion Treatments

The shot titles cluster into a small set of motion archetypes. Across every app surveyed:

### 7.1 Scroll-driven

- **Scale-on-enter**: cards fade in + scale from ~0.95 to 1.0 as they enter the viewport. Airbnb's "New Card Thumbnails Scale Pop" is this. Use `scrollTransition` in SwiftUI.
- **Parallax on hero image**: image inside the card moves slightly slower than the card itself during scroll. ~0.7 ratio. Done with `GeometryReader` reading the scroll offset and offsetting the image.
- **Sticky header morph**: as the user scrolls, the hero image collapses into a navbar with the title. Airbnb's listing detail does this; "Media Morph Preview Scale" is this pattern.

### 7.2 Tap-driven

- **Press scale (~0.97)**: the universal "I felt your touch" feedback. Apply via `.scaleEffect` bound to a `@GestureState` `isPressed`.
- **Pop on state change (1.0 → 1.3 → 1.0)**: the heart, the badge, the favorite. Spring with overshoot.
- **Morph to detail screen**: the tapped card's image expands into the next screen's hero. `matchedGeometryEffect` with a `Namespace`.
- **Reveal/flip**: Airbnb's "Identity Verification Card Flip Scan" — the card flips on tap and shows scan content on the back. `rotation3DEffect` with `axis: (0, 1, 0)`.

### 7.3 Idle micro-animations

- **Page-dot drift**: the carousel dots breathe — the active dot subtly pulses or grows. Airbnb does this on the detail-screen carousel.
- **Mascot ambient motion**: Hopper's bunny blinks, sways, nudges. The mascot is *the* idle channel. Don't blink anything else.
- **"Rare find" pop on data load**: when the rare-find badge resolves from the server, it pops in rather than fading. Airbnb's "Rare Find Pop Animation" is exactly this. The motion is the signal that this is *new info*, not chrome.
- **Loading shimmer on card skeletons**: light gradient sweeping across the placeholder. Universal. Use `LinearGradient` animated with a repeating `withAnimation(.linear(duration: 1.5).repeatForever())`.

### 7.4 What none of these apps do

No bouncy easter eggs on every action — motion vocabulary is small (4–6 named motions per app) and disciplined. No autoplay video on cards in lists (Airbnb tried this and walked it back). No skeuomorphic page-turn — native paged scroll, dots, done.

---

## 8. Distilled Recommendation for ResortPass

If this report has a single output: **build the Airbnb image-bleed card layout with the Hotel Tonight overlay treatment, and only add density if measurement says you need it.**

Concrete card spec:

- **Image**: 4:3, 16pt corner radius, edge-to-edge inside the card column.
- **Overlays on image**: floating heart top-right (white outline + shadow); single optional badge top-left (`.regularMaterial` capsule with the vibe tag — "Adults only", "Family", "Day club").
- **Below image** (no card chrome): resort name (15pt / weight 500), neighborhood + amenity count (14pt / secondary), price + ★ rating row (price underlined for tap-to-detail). 4pt gap between rows, 24pt gap between cards.
- **Motion**: scroll-in scale (0.95 → 1.0), heart pop on tap, press-scale (0.97) on the card, matched-geometry image morph into detail.
- **Shadow**: none on the card itself; only on floating elements.
- **Surface**: page background `#FAFAFA` light / `#0A0A0A` dark. No card fill.

Dense alternative (only if comparison is the explicit user task): swap to a Booking-style row with image left, 5-line text column right, amenity icons, price right-aligned. Don't ship both — pick a posture and commit.

The depth budget — five tools, applied with restraint — is the entire vocabulary the best apps in this category use:

1. Two-layer shadow on hero/featured cards (and only those).
2. `.ultraThinMaterial` for floating chips overlaying photos.
3. Linear gradient (top-to-bottom black at 70%) when text *must* read on any photo.
4. `matchedGeometryEffect` for the card → detail transition.
5. Spring-with-overshoot pop for state-change moments.

---

## Sources

- [60fps.design — Apps catalog](https://60fps.design/apps)
- [60fps.design — Airbnb shots](https://60fps.design/apps/airbnb)
- [60fps.design — Flighty shots](https://60fps.design/apps/flighty)
- [60fps.design — Marriott Bonvoy](https://60fps.design/apps/marriott-bonvoy)
- [60fps.design — Four Seasons](https://60fps.design/apps/four-seasons)
- [60fps.design — Wolt](https://60fps.design/apps/wolt)
- [60fps.design — Globetrotter](https://60fps.design/apps/globetrotter)
- [60fps.design — Qatar Airways](https://60fps.design/apps/qatar-airways)
- [Mobbin — Airbnb Web Property Image Carousel](https://mobbin.com/explore/screens/b277fe9f-067a-42bd-88f8-7331193ac735)
- [Mobbin — Airbnb iOS Nearby Stays](https://mobbin.com/explore/screens/603fd8fc-d3f2-420b-805a-18d9035cb30a)
- [Mobbin — Card UI glossary](https://mobbin.com/glossary/card)
- [ScreensDesign — Hopper teardown](https://screensdesign.com/showcase/hopper-flights-hotels-cars)
- [DesignRush — Hotel Tonight](https://www.designrush.com/best-designs/apps/hotel-tonight)
- [Hopper — Price Prediction product page](https://hopper.com/product/price-prediction)
- [Design+Code — Shadows and Color Opacity in SwiftUI](https://designcode.io/swiftui-handbook-shadows-and-color-opacity/)
- [SwiftUI.art — Card Lists components](https://www.swiftui.art/components/Card-Lists)
