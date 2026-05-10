# Premium Hospitality App Deep-Dive

A field study of ten shipping apps from the brands that define what "premium" looks like on a phone — what they actually do, how their cards are laid out, what makes them feel different from the generic OTA mush, and which of those patterns we can lift directly into ResortPass cards.

This is a working engineering doc. The goal isn't admiration — it's extraction. Every section ends with what's portable into SwiftUI.

---

## 1. Mr & Mrs Smith — Editorial Luxury

App Store ID 445834586. ~1.5M members, 4.5★ from ~2,900 reviewers (category mean ~3.85). Rebuilt by Cognitive Creators around 2020 — fresh architecture, not legacy patches.

**Hotel card layout.** Closest reference to where ResortPass should live aesthetically. Cards are dominated by full-bleed editorial photography — 16:9 or 4:3 hero, no inset, the card's rounded corner clips the photo. Hotel name below the image in a display serif at ~22–24pt, weight 500. Below that, a single-line metadata row: location, separator dot, then either a short editorial pull-quote ("Pssst. Over here") or the Smith Score (proprietary rating, numeral not stars). Price is deliberately de-emphasized — bottom-right in smaller tertiary text. Signal: "this is a place worth knowing about, the price is incidental."

**Search/discovery.** Two parallel modes — map and list — toggleable from a persistent control. Filters are segmented by intent (Adults, Children, Region) rather than a checkbox sheet; the regional split (UK, Europe, Americas, Asia-Pacific) is a primary nav axis, not a filter. Discovery is editorial: curated collections above the fold. Search bar is present but visually quiet — they're pushing browsing over searching.

**Color palette + typography.** Near-monochrome. Cream/off-white background (~#F8F5F0), near-black text (~#1A1A1A), single accent — a deep wine/terracotta for primary CTAs and wordmark. A high-contrast serif (custom, sits visually near GT Sectra / Recoleta) for hotel names and section headlines; a clean humanist sans (close to Söhne) for body and metadata. The two-typeface contrast does the work — there are almost no borders.

**What makes it feel premium.** It refuses to behave like an OTA. Price isn't the headline; hotel name is. Photography is full-bleed and edited, never thumbnail-y. Editorial copy gives every card a voice — these aren't database rows.

**Portable patterns:**
- Serif display + sans body pairing for hotel cards.
- Photography hero is full-card-width, no internal padding, card corner clips the image.
- Price in tertiary type weight, not as a CTA color.
- A short editorial line per property — even one sentence creates the "voice."
- Curated collections as a top-level entry point, not buried under a "filters" button.

---

## 2. Aman Resorts — Ultra-Luxury Minimalism

Aman doesn't ship a public booking app — their digital experience splits between a marketing-site-as-app and in-property guest tools. The web/PWA is the canonical reference: modular component system, mobile nav bypasses the global menu on resort pages and surfaces resort-specific nav instead.

**Card layout.** The "card" is barely a card. Edge-to-edge image, full viewport on mobile. Property name in a thin wide-tracked serif (~20pt, letter-spacing ~+0.05em) overlaid bottom-left, white on photo with a 30% scrim only when contrast demands. No metadata, no price, no CTA visible until you scroll. The first encounter is purely photographic.

**Search/discovery.** Essentially no search. Discovery is geographic — continent → country → property. The user drifts through, doesn't query. A fundamentally different mental model from OTA search.

**Color palette + typography.** Warm white (~#FAFAF7), graphite (~#2B2B2B), single warm-gold accent (~#A88B5C) used only on active states. A single serif family (visually near Lyon Display or ITC New Baskerville) at multiple weights, generous letter-spacing on uppercase labels. No sans-serif at all in the marketing surface. Body line-height 1.7, generous measure (~520px max).

**What makes it feel premium.** Restraint. The interface refuses to compete with the photography. No badges, no review stars, no "book now" until you've drifted three layers in.

**Portable patterns:**
- Photography-as-card with text overlay and minimal scrim.
- Wide-tracked uppercase labels for navigation/section headers.
- Generous max-width on body text (don't let lines stretch full-width).
- Single accent color, used sparingly enough that when it appears it has the weight of a notification.

---

## 3. Soho House — Membership Editorial

App Store ID 670256744. 175MB binary, iOS 15+. 4.9★ post-redesign (up from much lower pre-Elsewhen overhaul ~2022). Members use it primarily for transactional flow, not browsing.

**Card layout.** Soho House solves a harder problem than booking — hub for restaurants, screenings, fitness, accommodation, news, member networking. Home screen is modular, dynamically tailored per member by interests, history, location. Three card sizes:
- **Hero editorial card** — full-width, image-heavy, magazine headline in serif with a category eyebrow above ("HOUSE NOTES" / "WHAT'S ON") in small uppercase sans.
- **Booking module** — "Upcoming Bookings" stacks chronologically, image-left thumbnail, House name, date/time, chevron. Same type family as editorial — that consistency holds the brand.
- **Discovery row** — horizontally-scrolling cards with image and short title.

**Search/discovery.** Tab bar (post-redesign moved off a hamburger drawer). Geolocation-driven — "Where to Eat" and "What's On" surface what's near you first. Search is secondary.

**Color palette + typography.** Warm cream background, deep navy/near-black text. Custom serif (visually near Tiempos Headline) carries editorial; single neutral sans for transactional UI. Accent is muted ochre, used rarely.

**What makes it feel premium.** Same typographic system from magazine home feed to meeting-room booking timeline. No "marketing" vs. "functional" UI gap — the booking flow uses the same serif for "Confirm Booking" that the editorial uses for the cover headline. You're inside one world, not switching apps.

**Portable patterns:**
- Three-tier card system: hero editorial, transactional row, horizontal discovery row.
- Eyebrow-label-above-headline pattern (small uppercase tracking + serif headline below).
- Same display serif used in functional CTAs as in editorial — no marketing/product split.
- Geolocation-aware default modules.
- Tab bar over hamburger drawer — discoverability matters even at the premium tier.

---

## 4. Hotel Tonight — Last-Minute Mobile UX Benchmark

App Store ID 407690035. Owned by Airbnb since 2019. Celebrated for "three taps and a swipe to book." Gold standard for friction reduction.

**Card layout.** Dark theme is the brand. Black background (~#0A0A0A), cards as charcoal panels (~#1C1C1E), 12pt corners. Full-width photography header (16:9, swipeable carousel inside the card), then a structured info block — hotel name (sans, ~18pt, weight 500), drive time + neighborhood, a one-line editorial summary ("A loft-style outpost with a rooftop pool"), amenity chips (low-contrast rounded pills), and price right-aligned in their signature **purple accent** (~#7B5FFF) animating up from a smaller "from $" preface.

**Search/discovery.** Filters are presets — "Top Deals," "Most Premium," "Lowest Price." Reveal-on-tap menu, not a full sheet. GeoRates surface location-specific deals; Daily Drop is an exclusive countdown.

**Color palette + typography.** Black canvas, white type, purple accent. The only mainstream booking app that successfully uses dark mode by default — purple-on-black reads as nightlife/spontaneous, not utilitarian. Single sans family (visually GT America or Inter). No serif.

**What makes it feel premium.** Editorial property summaries — every hotel has a one-line voice. Apple Pay one-tap. No account required to book. Friction floor is so low that photography and copy can carry the brand.

**Portable patterns:**
- One-line editorial summary per property — the cheapest, highest-impact "voice" device.
- Filter presets over free-form sliders.
- Apple Pay + no-account-required as a premium trust signal.
- Price as accent-color animating up — pricing as a small celebration, not a number wall.
- Image carousel embedded in the card, not requiring a tap into a detail view.

---

## 5. 1 Hotels — Eco-Luxury, Biophilic Brand Translation

1 Hotels (SH Hotels & Resorts) leans on Bonvoy for booking — no heavy standalone consumer app. Brand site carries the digital identity. Built on biophilic design — moss walls, reclaimed oak, terrarium green, beach-shell white.

**Card layout.** Brand site cards: full-bleed nature photography with property name in white serif overlay. The Bonvoy listing shrinks into a generic chain card, but 1 Hotels properties remain visually distinguishable in Bonvoy search by photography palette alone — every image leads with greenery or water.

**Search/discovery.** Geographic. Only ~10 properties, so no filters needed.

**Color + type.** Tonal neutrals — beach-shell white (~#F5EFE6), coffee-table oak (~#8C7156), terrarium green (~#3A4A3F). Quiet humanist serif paired with clean sans. The brand voice is the photography grade, not the UI chrome.

**What makes it feel premium.** Color grading. Every image leans warm-green-natural. No bright cyan pools, no over-saturated sunsets. Desaturation reads as honest and considered.

**Portable patterns:**
- Photography color grading as a brand-consistency lever (more on this below).
- Earth-tone palette as a differentiator from the cyan-pool OTA cliché.
- Brand-site card approach (full-bleed photo + serif overlay) over generic chain-app card.

---

## 6. EDITION Hotels (Marriott × Ian Schrager) — Curated Minimalism

EDITION lives inside the Marriott Bonvoy app (App Store ID 455004730), which got a "one-button" redesign in 2025 emphasizing single-handed usability. As a brand, EDITION is Schrager's minimalist signature — whites and creams offset by dark oak, custom furnishings, moody photography, locally-rooted aesthetics.

**Card layout (within Bonvoy).** EDITION properties get the same Bonvoy card chrome as a Courtyard, which is the brand's biggest UX problem — chain-app density flattens the differentiation. Where EDITION shines is on its own marketing pages and in the in-property tablet experience: large moody photography, low-light interior shots, white type on near-black with generous tracking, single-line property descriptions.

**Color palette + typography.** Whites and creams, dark oak browns, deep blacks. No bright accent. Type is a thin geometric serif for property names paired with a wide-tracked uppercase sans for labels.

**What makes it feel premium.** Moody photography (low-key lighting, deep shadow, warm white balance) is the differentiator. Lobbies shot at dusk with practical lighting only. Typography uses positive letter-spacing on uppercase labels — a "fashion editorial" tic that reads as luxury.

**Portable patterns:**
- Moody photography brief: low-key lighting, deep shadows, warm white balance.
- Wide-tracked (positive letter-spacing) uppercase eyebrow labels above serif headlines.
- The cautionary tale: don't let the chain-app card chrome flatten property differentiation. ResortPass has a chance to give each resort its own visual treatment — Bonvoy doesn't.

---

## 7. The Hoxton — Boutique Neighborhood

The Hoxton (Ennismore / Accor) doesn't ship a significant standalone app — digital strategy is mobile web. Their site is a strong reference for what "app-feeling" mobile web looks like in the boutique segment.

**Card layout.** Tall portrait (~3:4), Hoxton wordmark upper-left of the image, neighborhood name in white sans below, property location below the image in sans. No serif. No prices on browse cards.

**Search/discovery.** Geographic browse — city, then neighborhood. No search. Each property page leads with a "Local Guide" in the voice of staff/locals — neighborhood walks, food picks — before any room/booking content.

**Color + type.** Cream, deep teal-green, clay/terracotta accents per property. Single playful custom sans for everything. The voice is what makes it feel boutique.

**What makes it feel premium.** "Premium" is the wrong word — Hoxton optimizes for "characterful." Local guide content leads. Per-property accent color. Typography playful but not cheap.

**Portable patterns:**
- Per-property accent color (each ResortPass resort could have a derived palette).
- "Local guide" / staff-voice content above booking content.
- Tall portrait card aspect ratio for properties with strong vertical photography.
- Wordmark/branding overlay on the image as part of the card composition.

---

## 8. Equinox Hotels — Wellness Performance Luxury

Equinox Hotels' app (built integrating with Equinox Fitness Clubs app) anchors a "performance luxury" positioning — hotel + fitness club + curated wellness. In-room bedside tablet centralizes blinds, lighting, temperature, and Rituals content. The mobile experience covers booking + on-property service + fitness scheduling.

**Card layout.** Equinox's design language is sharp, dark, high-contrast — closer to a fashion or fitness brand than a hospitality brand. Property cards use square or 4:5 portrait photography with deep saturation, bodies in motion or empty performance environments. White serif over black, with a thin red accent line. Booking/service cards are dense, list-style, with strong dividers and metric-style data display (treating fitness class slots like flight times).

**Color palette + typography.** Black (~#000000), white (~#FFFFFF), red accent (~#D81E2C) used very sparingly. Typography is a high-contrast serif (close to GT Super Display) for headlines, a tight monospace-adjacent sans for metadata. The monospace tic reads as "data, performance, precision."

**What makes it feel premium.** It refuses to be hospitable. There's no "warmth" in the design — it reads as elite, austere, and selective. The wellness content (Rituals, sleep modes, training plans) gives the app a depth that pure hotel apps don't have.

**Portable patterns:**
- Mono-adjacent or tight-tracked sans for metadata/data → reads as precise/premium.
- High-contrast serif headlines for property/experience names.
- Treat amenity time slots like flight departures — structured, scannable.
- A single restrained accent color used at low frequency.

---

## 9. Standard Hotels — Design-Led, Playful Boutique

The Standard doesn't ship a heavyweight standalone consumer app (the "Standard Hotel" listing on the App Store is unrelated property-management software). Consumer experience is web-first; the brand voice is the reference.

**Card layout (web/marketing).** Highly saturated photography — bright reds, hot pinks, neon. Standard wordmark in custom condensed sans. Square cards, edge-to-edge image, property name in big condensed sans bottom-left.

**Color + type.** Deeply branded — bright primary red (~#E4002B) is the signature. Custom condensed sans (close to Druk Wide) for everything. Black or red on white, occasionally inverted.

**What makes it feel premium.** Standard inverts the luxury trope — loud, saturated, playful. "Premium" here is brand confidence and cultural relevance, not restraint.

**Portable patterns:**
- Loud condensed sans for high-impact property names — works when paired with high-quality photography that can take the visual weight.
- Saturated photography as a brand signature (where Aman desaturates, Standard saturates — both work).
- Square card aspect ratio for grid-heavy layouts.

---

## 10. Airbnb (Plus, Luxe, and the 2024 Icons release) — Flagship Discovery

Not hotel-first, but the most-studied mobile travel UX in the world. 2024 Summer Release introduced Icons (curated once-in-a-lifetime stays) plus redesigned fonts, layout, colors, icons.

**Card layout.** Full-bleed square or 4:3 image carousel (swipeable in-card), heart top-right, host badge top-left when relevant. Below: title (serif-adjacent sans, weight 500), location/distance, dates, price ("$X total" — clarified post-2024). Pagination dots overlay the image. Wishlist heart sticks to the image, not the metadata.

**Search/discovery.** Category bar at the top — horizontally scrolling icons with labels (Cabins, Treehouses, Beachfront, Icons). Replaces traditional filter UI with a visual taxonomy. Search input collapses into a single pill ("Anywhere · Any week · Add guests") — expand-on-tap.

**Color palette + typography.** Off-white background, near-black text, signature Airbnb coral (~#FF385C) only on primary CTAs and wordmark. 2024 release introduced a custom Cereal-derived display face for headlines.

**What makes it feel premium (especially Plus/Luxe).** Photography quality control. Plus and Luxe properties pass a content-quality review; cards look the same as standard listings but the photography is dramatically more consistent. Quality lives in the imagery, not in a different card design.

**Portable patterns:**
- In-card image carousel with pagination dots (no need to enter a detail view to see more photos).
- Category bar with icons + labels as a top-level discovery primitive.
- Collapsed search pill that expands on tap (saves vertical space, signals "search lives here").
- Photography content quality is the differentiator, not the card chrome.
- Wishlist/heart action sticky to the image, not metadata.

---

## Synthesis: Top 3 Patterns That Combine Editorial + Character + Depth

After looking at all ten, three patterns recur in the apps that feel both editorial and characterful — and they're all portable into ResortPass.

### Pattern 1: Eyebrow-Headline-Voice Card Composition

The card composition that consistently reads as "editorial luxury" — used by Mr & Mrs Smith, Soho House, Belmond, Six Senses on their property cards:

```
[FULL-BLEED PHOTOGRAPHY — 16:9 or 4:3, no internal padding]
EYEBROW LABEL — small uppercase sans, wide-tracked, secondary color
Hotel Name In Display Serif — 22pt, weight 500
A single editorial sentence in body sans about the place.
metadata · separator · dot · price
```

The eyebrow gives a category ("Coastal escape" / "Members favorite" / "Pool day pick"). The serif name is the headline. The single-sentence editorial pull is the **voice** — it's the cheapest device for making a card feel curated rather than scraped. Three lines of copy do the work that ten review stars and twelve amenity icons fail to do.

For ResortPass: every card needs an editorial line. Even one sentence. "Cliffside infinity pool, midweek calm" beats "4.5★ · Pool · Spa · Bar."

### Pattern 2: Photography Color-Grading as Brand

Aman desaturates. 1 Hotels leans warm-green-natural. Standard saturates. Equinox high-contrasts. Hoxton goes warm-clay. The single most consistent signal of brand positioning across all ten apps is the **color grade of the photography**, not the UI chrome.

This means: the ResortPass photography pipeline matters more than the card CSS. If we can establish a content brief — "warm-natural, golden hour, no over-saturated cyan, real people not stock" — and apply a consistent grade across every resort hero image, the brand identity is 70% there.

For ResortPass: define a photography content brief and a post-processing LUT (lookup table) for any user-supplied imagery. Even a `CIFilter` color grade applied at display time can homogenize a mixed library.

### Pattern 3: Typographic Restraint + Two-Family Pairing

Every premium-feeling app uses two type families maximum:

| App | Display | Body / UI |
|---|---|---|
| Mr & Mrs Smith | Custom serif (GT Sectra-adjacent) | Söhne-adjacent sans |
| Aman | Single serif at multiple weights | (none — serif throughout) |
| Soho House | Tiempos Headline-adjacent | Neutral sans |
| Hotel Tonight | (none — sans only) | GT America-adjacent sans |
| Belmond | Serif display | Sans body |
| Equinox | GT Super Display-adjacent | Tight-tracked sans / mono |
| Airbnb | Cereal display (post-2024) | Cereal text |
| The Hoxton | (none — sans only) | Custom playful sans |
| EDITION | Thin geometric serif | Wide-tracked sans labels |
| Standard | (none — condensed sans only) | Condensed sans |

The "editorial luxury" subset (Smith, Aman, Soho House, Belmond, Edition) all pair a high-contrast serif with a humanist sans. The "performance / boutique" subset (Equinox, Standard, Hoxton) use a single sans with strong character.

For ResortPass, the Smith/Soho House model is the closest fit — pool/spa/resort content benefits from the editorial-magazine treatment. Recommended pairing:

- **Display serif:** New Spirit, GT Sectra, Recoleta, or Söhne Schmal — for hotel names and section headlines.
- **Body sans:** Inter, Söhne, or system `-apple-system` for UI, metadata, and CTAs.

Two weights only: 400 regular for body, 500 medium for emphasis. 600+ bold reserved for rare events.

---

## SwiftUI Implementation Notes

Concrete patterns for the ResortPass card system, in the order they're worth building.

### Card Anatomy

```swift
struct ResortCard: View {
    let resort: Resort

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-bleed image — no internal padding, card corner clips photo
            AsyncImage(url: resort.heroImage) { image in
                image.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Color(.secondarySystemBackground)
                    .aspectRatio(16/9, contentMode: .fit)
            }
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                // Eyebrow — small uppercase, wide-tracked
                if let eyebrow = resort.eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                }

                // Display serif — hotel name
                Text(resort.name)
                    .font(.custom("NewSpirit-Medium", size: 22))
                    .tracking(-0.3)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                // Editorial pull — single sentence, body sans
                Text(resort.editorialLine)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Metadata row — price as tertiary
                HStack(spacing: 6) {
                    Text(resort.location)
                    Text("·")
                    Text("from \(resort.priceFormatted)")
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
        )
    }
}
```

Notes:
- `RoundedRectangle(cornerRadius: 12, style: .continuous)` — `.continuous` (squircle) reads as iOS-native premium. The default `.circular` reads as web/Material.
- `.tracking(-0.3)` on display headlines — tighter tracking on large type signals confidence (a Geist principle that holds in iOS).
- `.tracking(1.2)` on uppercase eyebrows — positive tracking on small caps is the editorial tic.
- `.padding(20)` not 16 — the extra 4pt of breathing room is what separates premium from default.
- Border at 0.5pt with `.opacity(0.4)` — barely visible, only present where whitespace alone is insufficient.

### In-Card Photo Carousel (Airbnb-style)

```swift
TabView {
    ForEach(resort.images) { image in
        AsyncImage(url: image.url) { $0.resizable().scaledToFill() }
            placeholder: { Color(.secondarySystemBackground) }
    }
}
.tabViewStyle(.page(indexDisplayMode: .always))
.aspectRatio(16/9, contentMode: .fit)
.indexViewStyle(.page(backgroundDisplayMode: .interactive))
```

Embedded `TabView` with `.page` style gives the in-card swipe with pagination dots without writing a custom carousel. Works out of the box, looks native, doesn't require a tap into a detail view.

### Category Bar (Airbnb 2024-style discovery)

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 24) {
        ForEach(categories) { cat in
            VStack(spacing: 6) {
                Image(cat.iconName).renderingMode(.template)
                Text(cat.name).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(selected == cat.id ? .primary : .secondary)
            .overlay(alignment: .bottom) {
                if selected == cat.id {
                    Rectangle().frame(height: 2)
                        .padding(.bottom, -8)
                }
            }
        }
    }
    .padding(.horizontal, 20)
}
.scrollTargetBehavior(.viewAligned)  // iOS 17+
```

Categories like "Pool day," "Spa retreat," "Cabana," "Couples-only," "Family-friendly" — each becomes a top-level visual entry, replacing checkbox filter sheets.

### Color Palette (System)

Define in Asset Catalog with light/dark variants:

| Token | Light | Dark |
|---|---|---|
| `bg/canvas` | `#FAFAF7` (warm cream) | `#0A0A0A` |
| `text/primary` | `#171717` | `#EDEDED` |
| `text/secondary` | `#6B6B6B` | `#888888` |
| `text/tertiary` | `#A1A1A1` | `#5A5A5A` |
| `border/subtle` | `#E5E5E5` | `#1F1F1F` |
| `accent/primary` | `#3B5F4A` (deep moss — natural, premium) | `#6B9580` |
| `accent/danger` | `#B5483D` (terracotta) | `#D67566` |

Avoid the OTA cyan/blue trap. Deep moss + terracotta reads as natural-luxury rather than transactional.

### Photography Color Grading at Display

For mixed user-supplied imagery, apply a unified grade with `CIFilter` chained behind `AsyncImage`:

```swift
extension UIImage {
    func resortGraded() -> UIImage? {
        guard let ci = CIImage(image: self) else { return nil }

        let warmer = CIFilter(name: "CITemperatureAndTint",
            parameters: [
                "inputImage": ci,
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 5800, y: 8) // warmer, slight magenta
            ])?.outputImage

        let curves = CIFilter(name: "CIToneCurve",
            parameters: [
                "inputImage": warmer ?? ci,
                "inputPoint0": CIVector(x: 0, y: 0.04),    // lift shadows
                "inputPoint1": CIVector(x: 0.25, y: 0.22),
                "inputPoint2": CIVector(x: 0.5, y: 0.5),
                "inputPoint3": CIVector(x: 0.75, y: 0.78),
                "inputPoint4": CIVector(x: 1, y: 0.96)     // pull highlights
            ])?.outputImage

        guard let output = curves,
              let cg = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}
```

The grade above lifts shadows, pulls highlights, warms white balance — the signature "natural luxury" treatment. Apply it once per image and cache.

---

## Photography Conventions in Luxury Hospitality

Synthesizing across all ten apps:

**Composition.**
- Wide horizontals (16:9, 3:2) for environment shots; vertical 4:5 for rooms and details.
- Lead with environment (pool, lobby, view) before showing rooms.
- Negative space in the frame — let architecture breathe. Tight crops on detail shots only.
- Human presence is rare and editorial — never staged stock. When people appear, they're in motion or distant, never looking at camera.

**Lighting.**
- Golden hour (sunrise, sunset) for exterior/pool/garden shots — warm color temperature, long shadows.
- Practical light only for interiors at dusk — lamps, sconces, candlelight. Avoid overhead daylight for moody luxury (EDITION, Soho House) or use overhead daylight for fresh natural luxury (1 Hotels, Aman). Pick a lane.
- Avoid harsh midday sun for hero imagery.

**Color grading.**
- **Warm-natural grade:** lifted shadows, slightly warm white balance, desaturated greens and blues, retained warm tones in skin and wood. The Aman / 1 Hotels / Smith default.
- **Moody grade:** deep shadows, low key, warm white balance, high contrast in highlights only. The EDITION / Soho House / Equinox default.
- **Saturated grade:** maintained saturation, occasional film-grain texture, primary-color emphasis. The Standard / Hoxton default.
- **Avoid:** over-saturated cyan pools, magenta sunsets, HDR-flat midtones — these are the tells of OTA stock photography.

**Subject hierarchy.**
1. Environment / view / architecture
2. Pool / spa / signature amenity
3. Room interior
4. Detail (texture, food plating, towel folds, etc.)
5. People (rare, editorial)

**Format.** Shoot wide; crop in-app. Always have a 16:9 hero, 1:1 grid thumbnail, and 4:5 vertical for stories/detail views from the same source asset.

---

## Editorial Typography Pairings (Engineer-Ready)

The pairings used by the apps that successfully pull off editorial-luxury, with system-available fallbacks:

| Use | Pairing (premium) | Pairing (system fallback) |
|---|---|---|
| Editorial headlines (Smith / Soho House style) | New Spirit, GT Sectra, or Recoleta + Söhne | New York (display) + SF Pro Text |
| Ultra-luxury minimalism (Aman) | Lyon Display or Tiempos Headline (single family, multiple weights) | New York at multiple weights |
| Performance luxury (Equinox) | GT Super Display + GT America Mono | New York Bold + SF Mono |
| Boutique character (Hoxton / Standard) | Custom display sans (Druk, GT Walsheim) | SF Pro Rounded Display |

For ResortPass MVP without licensing budget: **New York + SF Pro Text** (both bundled with iOS) gets you ~85% of the Smith/Soho House aesthetic. New York is Apple's serif, designed to pair with SF, and reads as editorial without paying for a custom face.

```swift
// Headline
.font(.custom("NewYork-Medium", size: 22))
// Body
.font(.system(size: 15, weight: .regular))
// Metadata / eyebrow
.font(.system(size: 11, weight: .medium, design: .default))
.tracking(1.2)
.textCase(.uppercase)
```

When budget permits, the upgrade path is **GT Sectra Display** (or Pangram Pangram's free Editorial New) for headlines — that's what visually places ResortPass in the Smith / Soho House tier rather than the Bonvoy tier.

---

## Recommendations Summary

What to build first, in priority order:

1. **Adopt the eyebrow + serif name + editorial line card composition.** This is the single highest-leverage change. Even with system fonts and existing photography, this layout reads as editorial-luxury.
2. **Establish a photography content brief and apply a unified color grade at display time.** Mixed user-supplied photography is the biggest threat to premium feel. Grade it on the way out.
3. **Cap typography at two families, two weights.** New York + SF Pro Text. Regular and Medium only. Reserve Bold for rare events.
4. **Replace filter sheets with a category bar.** Visual taxonomy beats checkbox UX for premium feel and discoverability.
5. **Embed image carousel in cards, not behind a tap.** Airbnb's pattern. Native `TabView` with `.page` style does this in 6 lines.
6. **Use deep moss + terracotta accents, not OTA cyan.** Color is the cheapest brand differentiator.
7. **Write one editorial sentence per resort.** Even temporarily generated by hand at first. The card without a voice reads as a database row.

The throughline across all ten apps: **premium is not chrome, it is restraint plus voice.** The chrome is what every OTA already does. The voice — the editorial line, the photography grade, the typographic pairing, the eyebrow label — is the signal.
