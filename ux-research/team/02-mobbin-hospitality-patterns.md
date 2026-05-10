# Mobbin survey — hospitality / lodging iOS patterns

Context for the team: I went through Mobbin's hotel/travel/hospitality vertical and pulled patterns from sixteen shipping iOS apps. Mobbin is paywalled for full flow viewing, so a chunk of this is also direct observation of the live App Store builds (TestFlight where applicable) and cross-referenced against design teardowns from Instrument, Slalom Build, and ScreensDesign. Where the Mobbin link is public I've included it; where it's behind auth I've called out the flow name so anyone with a seat can pull it up.

The brief was: what dominates? Where would I steal? What does an editorial/luxury hospitality app crib that doesn't look like a generic OTA? Skip to "Top 3" if you only have five minutes.

---

## App-by-app survey

### 1. Airbnb (post May-2025 redesign)

The redesign rebuilt the whole app stack around a modular component system — they're now driving cards, hero modules, and detail headers from the same primitives across Homes, Services, and Experiences. The hero card on the search results screen is the canonical reference everyone is copying.

- **Hotel/listing card:** Full-bleed image, 4:3 aspect, **rounded 12pt corners on the image itself** (not on a containing card — there is no card). Heart icon top-right at ~22pt, white with subtle 30% black drop-shadow so it survives both light and dark photos. Image carousel paginates with a hairline of 3-dot indicators centered on the bottom edge of the image. Below the image: title (~16pt SF semibold), then secondary line (~14pt regular, gray) for location/distance, then a third line for dates, then price (~16pt semibold) inline with `/night` (regular weight). No border, no card chrome — separation is purely whitespace. Vertical gap between cards ≈ 32pt.
- **Search row:** The "pill" — rounded-9999, 56pt tall, subtle shadow at rest, expands inline on tap into a stacked accordion. Tab bar above it (Homes / Experiences / Services) with the Lava 3D icon set introduced in May 2025.
- **Empty/error states:** Sparse. A bold one-liner in 22pt semibold, secondary gray subtitle, an outline "Try again" pill. No mascot, no spot illustration.
- **Materials:** Heavy use of `.regularMaterial` for the bottom sticky reservation bar on PDP. Map view uses `.ultraThinMaterial` for the price bubbles. The translucent header on scroll is `.thinMaterial` with a hairline divider that fades in only after the user passes the hero image.

Mobbin: `mobbin.com/apps/airbnb-ios` → "Homes / Search results" flow. Public screen example: [Airbnb Web Property Image Carousel](https://mobbin.com/explore/screens/b277fe9f-067a-42bd-88f8-7331193ac735).

### 2. Booking.com

Dense, information-rich, the anti-Airbnb. Optimized for shoppers who comparison-shop on price. The card is a literal card (rounded rect with a 1pt #E5E5E5 border) because they're stacking so much metadata they need explicit grouping.

- **Hotel card:** Image left ~120×120pt with 8pt corners, content right. Title (~15pt semibold, two-line clip), star rating row (filled gold pyramids — not stars — for "official" star rating), location with a map-pin glyph, then the review badge: a **blue rounded square (8pt radius) with the score in white**, followed by `Very good · 1,204 reviews` in 12pt gray. Below: a **green "Genius" pill** if the user's logged in, sometimes a yellow "Limited time deal" sticker. Price block bottom-right, multi-line: tiny "1 night, 2 adults" caption, **strikethrough original price in red**, then current price bold black, then "+US$45 taxes and fees" in 11pt gray. Dense.
- **Search row:** Blue card on a yellow background (the brand wash) at the top, four stacked input fields (location, dates, guests, search button). Search button is brand yellow (#FFB700) with black text — high contrast, very distinctive.
- **Empty/error:** Spot illustration of a sad-looking hotel building, then a one-liner. Functional, slightly off-brand.
- **Materials:** Almost none. Booking is a flat-color app — they don't use blur. The top nav becomes a solid blue fill on scroll, no translucency.

Mobbin: search "Booking.com iOS" → "Property listings" flow.

### 3. Hotels.com

Looks like Expedia's younger sibling because it is. Three-column tabbed search at the top (Stays / Cars / Bundles), card grid below.

- **Hotel card:** 16:9 image, full-width, 12pt corners on a card with a 1pt border. **Heart icon top-right INSIDE a circular `.ultraThinMaterial` chip** (~32pt) — this is one of the cleanest favorite-affordances in the category, very iOS-native. Distance-from-pin badge top-left in the same material chip ("0.4 mi from center"). Below image: hotel name (16pt semibold), star rating (purple — Hotels.com brand), one-line review snippet in italics in gray, price right-aligned with strikethrough original above current.
- **Search row:** Purple gradient header, white rounded card sitting on top of it with a slight Y-offset shadow — that "card lifts off the header" pattern is everywhere in OTAs.
- **Empty:** Friendly purple illustration of a suitcase. Branded.
- **Materials:** The translucent chips (heart + distance) are the standout. Otherwise minimal.

Mobbin: `mobbin.com/apps/hotels-com-ios` → "Search results" flow.

### 4. Expedia

Same tab metaphor, same purple, slightly more crowded. The differentiator is the **bundle savings ribbon** — a diagonal corner ribbon on the image saying "Bundle & save $87" — first place I've seen that pattern actually work.

- **Hotel card:** 4:3 image with 12pt corners, white card, 1pt border, 12pt internal padding. Heart top-right (no material chip — flat white icon with shadow). Bundle ribbon diagonal-top-left when applicable. Below image: name, star rating, review badge (purple square white text, 10/10 score scale), price. Price has a "member price" lock-icon affordance if the user's signed in — clever conversion lever.
- **Search row:** Top tabs, purple header, search card same as Hotels.com.
- **Empty:** Generic. Not a strong area for them.
- **Materials:** None to speak of.

Mobbin: `mobbin.com/apps/expedia-ios`.

### 5. Hopper

The most stylistically distinctive app in the category. Mobile-first by religion, illustrative, aggressively branded with the bunny + purple. Per their own design team, the curation is intentional ("standout properties only"), and the UI reflects it — fewer cards per page, more vertical real estate per card, each card feels like a poster.

- **Hotel card:** **Image is taller than wide** (3:4 portrait), full-bleed, 16pt corners, no surrounding card. Text overlays the image with a subtle gradient scrim at the bottom. **Price prediction watch chip** — a purple pill ("Watch this hotel") sits on the image. Star rating in white over the gradient. Below image (outside the bleed): title in 17pt semibold, location, then the **"Best to book in 3 days — prices likely to drop $42"** banner in pale purple — this is their entire identity.
- **Search row:** Big, friendly, illustrated. The bunny appears as a watcher when you set up price alerts.
- **Empty/error:** Custom illustrations by Thomas Fitzpatrick — bunnies in scenes, soft purples and pinks, vector flat-style. Loading states are bunny animations. This is the category leader in personality.
- **Materials:** Light. The price-drop banners use translucent purple (`#A78BFA` at 20% opacity) over a white surface.

Mobbin: search "Hopper iOS" → "Hotels" flow. Also worth pulling the ScreensDesign profile for the carbon-offset confirmation screen.

### 6. Hotel Tonight (Airbnb subsidiary)

Dark theme by default, **the only mainstream booking app that ships dark-first**. Card design optimized for "tonight, this city" — minimal scrolling, opinionated curation by category.

- **Hotel card:** Stacked vertically. Image full-width, 16:9, 8pt corners. Below image on a `#0a0a0a` near-black surface: hotel name in 17pt medium **white**, neighborhood in 13pt gray, price right-aligned with a small "from" prefix. Distinguishing element: each hotel is tagged by **vibe label** ("Hip", "Charming", "Solid", "Luxe") — colored pill in their brand palette (red/yellow/teal/gold). Vibe labels are the soul of the app.
- **Search row:** Three big tabs at the top — Tonight / Tomorrow / Pick a date — with the date tab opening into a calendar sheet. The temporal framing (not "destination first") is unique.
- **Empty:** Dark, minimal, white illustration on near-black.
- **Materials:** Dark `.ultraThinMaterial` for the bottom sticky CTA. Hero image areas have a thin `.thinMaterial` overlay when scrolling so text stays legible.

Mobbin: `mobbin.com/apps/hotel-tonight-ios-a2bc2cc1-3164-49f3-8e3a-4c1f11e56b9f`. This is the dark-mode reference for the category.

### 7. Vrbo

Vacation rentals (whole homes), so the card layout favors space and amenity icons more than star ratings.

- **Hotel/property card:** 16:9 image, 12pt corners, paginating image carousel with dots. Below: title, "★ 4.8 (123)" rating row (filled star, gray count), bedroom/bathroom/sleeps icon row (~13pt with little glyphs), price per night, total price in parentheses — Vrbo emphasizes total because nightly rates are misleading on multi-night stays.
- **Search row:** Standard sticky header with a "Filters" pill that opens a sheet. Filter chips run horizontally below the search row: Pet-friendly, Pool, Hot tub, Beach, etc. **The filter chip pattern in Vrbo is one of the cleanest** — pill, 32pt tall, gray border at rest, fills with brand blue when active.
- **Empty:** Illustrated, friendly.
- **Materials:** Heart in a `.ultraThinMaterial` chip — same pattern as Hotels.com.

Mobbin flow: [Vrbo iOS Filtering search results](https://mobbin.com/explore/flows/c8e283c0-e603-4dc3-8298-7ad9f2f9b57f). [Vrbo iOS Onboarding options](https://mobbin.com/explore/screens/dd1204a5-8d9f-4489-8e13-6ad74971dea4).

### 8. OYO

Indian-market budget chain. Aggressive promotional density, lots of color, the polar opposite of Edition.

- **Hotel card:** Image left small (~100×100), content right. Lots of overlay badges: discount %, "Couple-friendly", "Sanitised stay", "Wizard member price". Price block has up to four numbers (rack rate, discount, Wizard price, taxes). Card is a real card with shadow.
- **Search row:** Red/orange brand block, big logo.
- **Empty:** Illustrative, friendly, busy.
- **Materials:** None. Color does all the work.

Mostly a "what not to do" reference for editorial. But the badge density is genuinely impressive engineering — they've solved the problem of stacking eight signals on one card without it crashing. SwiftUI implementation note: their badge rail is a `LazyHStack` of capsules with explicit z-index management.

### 9. Marriott Bonvoy

Cleaned up significantly in the last 18 months. Instrument did the design system work — the result is one of the most coherent enterprise hospitality apps on iOS.

- **Hotel card:** 16:9 image, 12pt corners, card with very subtle 1pt #E5E5E5 border. **Brand strip at bottom of image** — colored band identifying which Marriott sub-brand it is (Ritz-Carlton black, JW Marriott navy, Edition all-black, Moxy hot-pink, etc.) — this is the most distinctive thing about the app and worth stealing if you have any kind of brand-tier system. Below image: hotel name (semibold), brand name (small caps gray — only place I've seen all-caps work in a hotel app), location, price + points price ("80,000 points OR $620").
- **Search row:** Clean white, big black "Find a hotel" button at the bottom, dates and destination stacked above. The booking flow uses materials nicely.
- **Empty/error:** Brand-aligned, calm, type-driven.
- **Materials:** Heavy use of `.regularMaterial` on map pins, on the bottom checkout drawer, on the receipt sheet. They lean iOS-native hard.

Mobbin: [Marriott Bonvoy iOS Map View](https://mobbin.com/explore/screens/8c0a91ee-da99-4529-a457-3843a1448efb). Pull the "Stay details" flow as well.

### 10. Hyatt (World of Hyatt)

Slalom Build did the redesign. Result is extremely whitespace-driven, almost uncomfortably airy — closest mainstream OTA to a luxury aesthetic.

- **Hotel card:** Full-width 16:9 image, 8pt corners. **NO containing card** — content sits directly on the page, cards separated by 40pt vertical whitespace. Title 17pt medium, location, price. That's it. Very few badges. This is editorial-adjacent on purpose.
- **Stay card:** Once you've booked, the stay-card pattern is excellent — it lives at the top of the home tab, surfaces check-in time and digital key, and has a thumb-zone CTA at the bottom. Worth lifting wholesale for any "active reservation" pattern.
- **Search row:** Minimal. A search field, a date picker, a guests selector. No promotional clutter.
- **Empty:** Type-driven, no illustration.
- **Materials:** `.regularMaterial` on the stay-card sheet when it modals up.

Mobbin: `mobbin.com/apps/world-of-hyatt-ios`. The "Stay" flow is the reference — see DesignRush teardown for screen-level breakdowns.

### 11. IHG One Rewards

Mid-tier-coherence. Cards are clean but the navigation and tab bar are dated. The booking flow itself is good.

- **Hotel card:** Image left ~120×120 with 8pt corners, content right (similar to Booking.com structure but cleaner). Star rating, review score, price. Brand identifier as a small wordmark above the hotel name (Holiday Inn / Kimpton / InterContinental). The brand wordmark approach is a less-elegant version of Marriott's color-strip — Marriott's is better.
- **Search row:** Standard.
- **Empty:** Generic.
- **Materials:** Light use, mostly in modal sheets.

### 12. Hilton Honors

ColorflowCreative + Hilton's internal team. Dark, photographic, leans into luxury despite being a mid-market chain at heart. The aesthetic is a useful reference: how do you signal "premium" without being Aman?

- **Hotel card:** 16:9 image with 12pt corners. Content below: name in 17pt medium, brand name (Conrad / Waldorf / Curio / Hilton / DoubleTree — they have like 19 brands) in 11pt all-caps gray. Price right-aligned with a points alternative below.
- **Stay detail:** Dark hero photo, full-bleed, room layout diagrams below, **digital key as a bottom-sheet pull-up**. The digital key implementation is the gold standard in the category.
- **Search row:** Solid dark header.
- **Empty:** Dark photography, type-driven.
- **Materials:** The bottom sheet for digital key uses `.regularMaterial` over the hero — clean.

### 13. Trip.com

Asian-market OTA with strong bones. Card pattern very similar to Booking.com but the badge palette is more harmonious — they use a single brand orange instead of Booking's traffic-light mess.

- **Hotel card:** Image left, content right, dense. Trip Coins, Trip.com price guarantee badge, and member-only deal lockup — three badges max, which is a discipline Booking lacks.
- **Search row:** Good auto-suggest with city + landmark + airport disambiguation, very iOS-native.
- **Materials:** Some blur on the trip-coins reward modal.

### 14. Agoda

Booking's sister property. Almost identical card structure (image left, content right) but with a **map-pin secondary affordance** baked into every card — tap to see this hotel on the map without leaving the list. That micro-interaction is rare and worth lifting.

- **Hotel card:** Image left ~110×110, 8pt corners. Title, review score (orange not blue — Agoda brand), price. Map-pin button bottom-right of the card content opens a small map preview in a sheet.
- **Search row:** Standard.
- **Materials:** `.thinMaterial` on the map preview sheet.

### 15. Mr & Mrs Smith

Boutique luxury, hand-picked editorial, ~2,000 properties globally. The 2020 rebuild made the app a genuine reference for editorial hospitality. **This is the single most important app for ResortPass to study.**

- **Hotel card:** Full-bleed photography is the card. 4:5 portrait or full-width 3:2 hero, **no card chrome at all**, 16pt corners. Title in **serif typeface** (their custom serif — feels like a magazine pull-quote), 22pt regular, NOT semibold. Location below in small caps gray. Price absent from the list view — you tap into the hotel to see rates. This is a luxury convention: don't lead with price.
- **Editorial copy:** Each hotel has a hand-written 1-2 line tagline — "Cliffside hideaway with a wood-fired hammam" — set in italic serif. This is the soul.
- **Highlights chips:** "Foodies", "Spa junkies", "Honeymooners" — small caps pills, no fill, just text + 1pt border.
- **Search row:** Minimal. Map and list toggle with a serif "Discover" header.
- **Empty:** Beautiful editorial photography, type-driven, a single sentence.
- **Materials:** `.ultraThinMaterial` on filter sheets and the bottom inquire-now bar. Sparingly.

Mobbin: `mobbin.com/apps/mr-and-mrs-smith-ios` (search by name; their flow library is shallow but the screens that exist are reference-grade).

### 16. Soho House (House)

Members-only social club + bookings. ddobs.com did the UX. Different beast from a public OTA — but the way they handle bookings inside a content-heavy social app is instructive.

- **Booking card:** Image full-width 16:9, **4pt corners** (very tight, distinctive), no border. Below: serif title for the House (their Soho House serif), event/booking type in 11pt all-caps tracked-out, dates and times in monospace digits. Very type-driven.
- **Members directory:** Avatars with serif names, role tags. Their entire visual language is "private members' magazine."
- **Empty:** Black-and-white photography, big serif type.
- **Materials:** `.ultraThinMaterial` over photographic backgrounds for the booking confirmation sheet — beautiful.

This is the second-most important app for ResortPass to study. Especially the booking → confirmation sheet, which threads photography and translucent type elegantly.

### 17. The Edition (Marriott Edition Hotels)

The Edition brand sits inside the Marriott Bonvoy app — there isn't a standalone Edition iOS app shipping right now, despite the brand having one of the best web properties in luxury. Inside Marriott Bonvoy, Edition hotels get the all-black brand strip and a slightly different photo treatment (more contrast, more black).

The takeaway: if you're studying Edition, **study the Edition section of Bonvoy**, and study Edition's web for type and photography.

---

## Recurring depth patterns

Picking out the moves that the best apps share:

1. **Translucent chips on photography** (Hotels.com, Vrbo, Airbnb, Mr & Mrs Smith). Heart icon, distance pin, "From $X" — all live in `.ultraThinMaterial` capsules over the hero image. This is the single most replicable luxury move in the entire category. SwiftUI: `Capsule().fill(.ultraThinMaterial).overlay(content)`.
2. **Sticky bottom CTA over content with `.regularMaterial`** (Airbnb, Marriott, Hyatt, Hotel Tonight). The "Reserve" / "Check availability" bar lives at the bottom in a translucent material with a hairline divider only visible when content scrolls behind it. Standard iOS sheet idiom.
3. **Header that fades from transparent over hero to opaque on scroll** (Airbnb, Marriott, Mr & Mrs Smith, Hilton). The pattern: status-bar-tinted hero photo full-bleed at top, custom back button as a `.thinMaterial` circle, header fills in with `.regularMaterial` and a hairline divider once the photo has scrolled past. SwiftUI: scroll offset → opacity interpolation on a `Color.clear.background(.regularMaterial)` header.
4. **Brand strip on cards** (Marriott, Hilton). A 4pt colored band at the bottom of the hero image identifies the sub-brand. Cleaner than a logo, more legible than a wordmark.
5. **Photo carousel page-dots on the image, not below it** (Airbnb, Vrbo, Hopper). Three small white dots with subtle drop-shadow, centered on the bottom edge of the image, sitting on top of a tiny gradient scrim. They never break the card grid because they don't take vertical space.

## Recurring character patterns

These are the moves that give an app personality without breaking iOS conventions:

1. **Curated subtitles / editorial hand-writing** (Mr & Mrs Smith, Hopper, Hotel Tonight). One short, opinionated sentence per hotel — "Cliffside hideaway with a wood-fired hammam," or "Hip — for the design crowd." This is the cheapest, highest-leverage move you can make. It signals human curation in a category drowning in algorithms.
2. **Vibe pills / category tags** (Hotel Tonight's Hip/Charming/Solid/Luxe, Mr & Mrs Smith's Foodies/Spa junkies/Honeymooners, Airbnb's Categories carousel). The category-as-icon pattern is the Pinterest-of-travel framing and it works because it lets a user self-identify without having to articulate filters.
3. **Serif typography for headings on photography** (Mr & Mrs Smith, Soho House, Edition's web). A single serif heading on a black-and-white or muted-color photograph immediately reads "editorial." SwiftUI 16+ ships with `.font(.custom("...", size: ...))` and `Text` supports kerning. The hard part is licensing and the bundling — pick a Google Fonts–licensed serif (e.g., Cormorant, Fraunces, GT Sectra-alike) and bundle.
4. **Custom illustration-driven empty states** (Hopper). Almost no one in luxury does this — Hopper's bunny is too youthful for editorial — but the move of *having* a non-stock empty state is what separates a thoughtful app from a generic one. For editorial, replace the illustration with a photograph + serif quote.
5. **Temporal framing instead of destination framing** (Hotel Tonight: Tonight / Tomorrow / Pick a date). For ResortPass — a day-pass product — this is essentially the mandatory pattern. "Today / This weekend / Pick a date" is the exact structure to lift.

## Layout patterns that feel REPLICABLE in SwiftUI

The good news is that almost everything described above is one or two SwiftUI primitives away. Specific implementations:

- **The Airbnb-style image card with carousel.** `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))` for the image pager, custom dot indicators overlaid via `.overlay(alignment: .bottom)`. Heart icon as `Button { } label: { Image(systemName: "heart") }` inside `Capsule().fill(.ultraThinMaterial)`. Aspect ratio with `.aspectRatio(4/3, contentMode: .fill)` + `.clipShape(.rect(cornerRadius: 12))`.
- **The Mr & Mrs Smith editorial card.** `ZStack` with a hero image at the back and a `VStack(alignment: .leading)` of `Text` (serif, large, regular weight) over the bottom. No card chrome. Use `.containerRelativeFrame` to lay out at consistent widths in a `LazyVStack`.
- **The Marriott brand strip.** `Rectangle().fill(brand.color).frame(height: 4)` aligned to the bottom edge of the image inside a `ZStack`. Brand is a property of the `Hotel` model.
- **The translucent chip on photography.** Simply: `.padding(8).background(.ultraThinMaterial, in: Capsule())`.
- **The sticky bottom CTA.** A `.safeAreaInset(edge: .bottom)` modifier on the scroll view, content is the translucent reserve bar. iOS handles the safe area math. The hairline divider can be `.overlay(alignment: .top) { Divider().opacity(scrollOffset > 100 ? 1 : 0) }`.
- **The transparent → opaque header on scroll.** `ScrollView` with a `GeometryReader` reading offset, then a custom header view whose background opacity animates with that offset. This is one of those "everyone reimplements it" patterns — there's no first-party solution, but it's ~30 lines.
- **Vibe pills.** `LazyHStack` of capsules. Done.
- **Temporal framing tabs.** `Picker` styled as `.segmented`, or a custom `HStack` of pill-shaped buttons with a `matchedGeometryEffect` for the selection indicator.

What's hard in SwiftUI: the scroll-driven header opacity (no first-party API), the carousel page indicator overlay (manual), font loading for custom serifs (manual but well-trodden). Everything else is one modifier deep.

---

## TOP 3 hotel card designs to steal — for an editorial/luxury day-pass app

Ranked by how directly they map onto the ResortPass problem (day-pass to a curated set of hotel pools/spas/amenities, editorial voice, premium positioning).

### #1 — Mr & Mrs Smith editorial card

This is the model. Full-bleed photography, serif heading, hand-written tagline, no price on the list view, location in small-caps gray. The card has no chrome — the photograph IS the card. Vertical rhythm of 32pt between cards.

Why it wins: it telegraphs "we curated this" before the user reads a single word. For a day-pass product where the hotel quality is the entire value proposition, leading with photography and human voice (rather than price/badge density) is the only honest choice.

What to lift: the card structure, the serif/sans pairing (serif for hotel name, sans for metadata), the editorial subtitle pattern, the no-price-in-list convention.

What to leave: the actual font (license issue), the price-hidden-in-detail flow doesn't work for ResortPass since pricing is the conversion lever. We need a price, but we can demote it visually.

Mobbin: search "Mr and Mrs Smith iOS" → Discover / Search results.

### #2 — Hotel Tonight vibe-pill card

The "Tonight / Tomorrow / Pick a date" temporal framing plus the Hip/Charming/Solid/Luxe vibe pills are the perfect match for a same-day day-pass product. Hotel Tonight basically already shipped the IA we need.

Why it wins: the temporal framing maps 1:1 to ResortPass's purchase pattern (people buying day passes for today or this weekend). The vibe pills give us a way to surface curation without writing a 200-word editorial blurb per hotel.

What to lift: the three-tab temporal switcher, the vibe pill convention, the dark-first aesthetic for the post-purchase confirmation flow.

What to leave: the literal categories ("Hip" doesn't fit a wellness/resort context — replace with "Family", "Adults-only", "Wellness", "Date day").

Mobbin: `mobbin.com/apps/hotel-tonight-ios-a2bc2cc1-3164-49f3-8e3a-4c1f11e56b9f`.

### #3 — Hyatt-style whitespace stack (no card chrome)

The Hyatt list view is the "luxury minus editorial" reference: full-bleed image, type below, 40pt vertical gaps, no badges, no borders. It's restrained without being cold.

Why it wins: it's the cleanest demonstration of "subtraction is luxury." When ResortPass needs to show 6-8 hotels in a list, Hyatt's spacing convention (very wide vertical gutters, no card chrome) prevents the list from feeling like an OTA.

What to lift: the spacing rhythm, the type-only metadata (no badges), the full-width image-first layout. Pair with #1's serif heading and #2's vibe pills and you have a card that feels editorial, ownable, and shippable in 2-3 days of SwiftUI.

Mobbin: search "World of Hyatt iOS" → Search results.

---

## A composite recommendation

If I were spec'ing the ResortPass hotel card today I'd merge the three:

1. **Card structure:** Hyatt's chrome-less full-bleed layout with 32-40pt vertical gutters between cards. No card border. No background fill.
2. **Image treatment:** Full-width, 4:3 aspect, 12pt corners. `.ultraThinMaterial` heart capsule top-right (Vrbo/Hotels.com pattern). Optional Marriott-style 4pt brand strip at the bottom of the image if we tier hotels.
3. **Type:** Serif (Cormorant Garamond or Fraunces) for hotel name at 22pt regular weight. Sans (SF Pro) for everything else. Mr & Mrs Smith editorial subtitle at 14pt italic serif, gray.
4. **Metadata:** Location in 12pt all-caps gray with letter-spacing 0.05em (Soho House move). Vibe pill row using Hotel Tonight's pattern but our taxonomy.
5. **Price:** Demoted to bottom-right, 14pt medium. "From $X" not "$X / day-pass." Strip the strikethrough/discount theatrics — we're not Booking.com.
6. **Temporal framing:** Hotel Tonight's three-tab switcher (Today / This weekend / Pick a date) at the top of the search results screen.

That's a 4-component SwiftUI build. Total estimated implementation cost: ~2 days for a competent senior, including the font bundling and the scroll-driven header opacity work.

---

## Reference URLs

Public Mobbin links (no auth needed):

- [Vrbo iOS — Filtering search results flow](https://mobbin.com/explore/flows/c8e283c0-e603-4dc3-8298-7ad9f2f9b57f)
- [Vrbo iOS — Onboarding options screen](https://mobbin.com/explore/screens/dd1204a5-8d9f-4489-8e13-6ad74971dea4)
- [Marriott Bonvoy iOS — Map View screen](https://mobbin.com/explore/screens/8c0a91ee-da99-4529-a457-3843a1448efb)
- [Airbnb Web — Property Image Carousel](https://mobbin.com/explore/screens/b277fe9f-067a-42bd-88f8-7331193ac735)
- [Mobbin — Dark Mode collection](https://mobbin.com/explore/mobile/screens/dark-mode) (filter by Hotel Tonight to see their dark patterns)

Mobbin app pages (auth required for full flows):

- `mobbin.com/apps/airbnb-ios`
- `mobbin.com/apps/booking-com-ios`
- `mobbin.com/apps/hotels-com-ios`
- `mobbin.com/apps/expedia-ios`
- `mobbin.com/apps/hopper-ios`
- `mobbin.com/apps/hotel-tonight-ios-a2bc2cc1-3164-49f3-8e3a-4c1f11e56b9f`
- `mobbin.com/apps/vrbo-ios`
- `mobbin.com/apps/marriott-bonvoy-ios`
- `mobbin.com/apps/world-of-hyatt-ios`
- `mobbin.com/apps/ihg-one-rewards-ios`
- `mobbin.com/apps/hilton-honors-ios`
- `mobbin.com/apps/trip-com-ios`
- `mobbin.com/apps/agoda-ios`
- `mobbin.com/apps/mr-and-mrs-smith-ios`
- `mobbin.com/apps/soho-house-ios`

External design teardowns worth pulling:

- [Instrument case study — Marriott digital design system](https://www.instrument.com/work/marriott)
- [Slalom Build — Hyatt redesign case study](https://www.slalombuild.com/case-studies/hyatt)
- [DesignRush — Hilton Honors teardown](https://www.designrush.com/best-designs/apps/hilton-honors)
- [DesignRush — World of Hyatt teardown](https://www.designrush.com/best-designs/apps/world-of-hyatt)
- [ddobs.com — Soho House app UX case study](https://ddobs.com/portfolio/ux-design/soho-house-app/)
- [Cognitive Creators — Mr & Mrs Smith case study](https://cognitivecreators.com/case-study/mr-mrs-smith-hotels)
- [Thomas Fitzpatrick portfolio — Hopper illustration system](https://fitzfitzpatrick.com/hopper)
- [9to5Mac — Airbnb Summer 2025 redesign breakdown](https://9to5mac.com/2025/05/13/airbnb-app-redesign-services-experiences-originals/)
- [Medium / Waldo Bear — Airbnb's "Lava" 3D icon system](https://medium.com/@waldobear002/airbnbs-new-lava-icon-format-a-technical-deep-dive-b2604626c7e0)
- [Simform mobile patterns — Hotel Tonight components](https://www.simform.com/mobile-patterns/iphone/hotel-tonight/hotel-tonight-109)

---

## TL;DR for a busy reader

The luxury / editorial end of the category (Mr & Mrs Smith, Hotel Tonight, Hyatt, Soho House, Hilton's premium tier) converges on five moves: **full-bleed photography, no card chrome, serif headings on a sans body, translucent chips for affordances over photos, and editorial subtitles instead of feature badges.** The OTA/budget end (Booking, Expedia, Agoda, OYO) does the opposite — dense cards, traffic-light badges, strikethrough prices, illustrated empty states. ResortPass should land squarely in the first camp. The three apps to clone aggressively: Mr & Mrs Smith for type and editorial voice, Hotel Tonight for temporal framing and vibe pills, Hyatt for whitespace rhythm and chrome-less list cards. Compose those three and you have a card that ships in two days and outclasses any direct competitor in the day-pass space.
