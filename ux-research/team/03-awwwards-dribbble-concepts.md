# 03 — Awwwards / Dribbble / Behance: visionary hotel-card concepts

> Survey of award-winning and high-engagement travel and hotel mobile work, biased toward
> editorial / magazine-grade concepts with depth, dimensionality, and character. The lens
> throughout is "what can a SwiftUI engineer steal and ship in five days?"

---

## TL;DR (read this first)

The strongest editorial hotel cards on Dribbble, Behance, and Awwwards in the last
twelve months stop looking like product cards and start looking like **magazine
plates**. Three observations recur:

1. **Image is the card.** The photograph is not framed *inside* a card chrome —
   it *is* the chrome. Type sits on top, on the side, or in a contrasting plate
   that breaks the photo's bounding box.
2. **Two-typeface tension.** A display serif (Tiempos, Canela, GT Sectra,
   Editorial New, Recoleta) carrying the property name; a precise grotesque
   (Söhne, Inter, GT America, Neue Haas) carrying metadata. Bold pairing
   without ornament.
3. **Depth is layered, not glossy.** Multiple soft drop shadows + image
   bleeds + small offset rotations. Glassmorphism appears, but the strongest
   work has moved past it toward "physical paper on a warm background."

Skip to **§4 Top 5 stealable patterns** if you want the action items.
Skip to **§6 Color palette inspiration** if you want hex codes.

---

## 1. Top concepts surveyed

These are the references I'd send to a designer-engineer pair if they had one
afternoon to absorb the genre. Every URL was live as of survey time.

### 1.1 Hedwig: Curated Travel — Awwwards Honorable Mention, April 2026
- URL: <https://www.awwwards.com/sites/hedwig-curated-travel>
- Designer: catarisso (Readymag)
- **What stands out:** Built on Readymag, so the layout is unapologetically
  editorial — full-bleed photography blocks crashing into wide-margin type
  panels. Property names set in a high-contrast serif at hero scale. Color
  almost entirely absent except for one warm sand background and deep ink
  text. No card chrome at all; the photograph + a single horizontal hairline
  + caption metadata is the entire card.
- **Steal:** the "no chrome, only photo + hairline + caption" composition.
  Easy to port to a SwiftUI `VStack` with a `Divider` whose color is a tinted
  ink, not a gray system separator.

### 1.2 Tribe Stays — Awwwards Honorable Mention, April 2026
- URL: <https://www.awwwards.com/sites/tribe-stays>
- Designer: Lumina
- **What stands out:** Asymmetric grid of stay cards. Each card is a tall
  portrait photograph with a small "title plate" — a horizontal slab of solid
  color (cream, rust, or charcoal) docked to the bottom-left corner of the
  image, breaking the rectangle. The plate carries property name + one-line
  descriptor. No price on the card itself; price lives in the detail view.
- **Steal:** the offset title plate. Trivially expressible in SwiftUI as an
  `overlay(alignment: .bottomLeading)` with negative `.offset(x: -16, y: 16)`.

### 1.3 Explore Primland — Awwwards SOTD + Developer Award, February 2026
- URL: <https://www.awwwards.com/sites/explore-primland>
- Designer: Outpost
- **What stands out:** Cinematic photography, parallax-scrolled imagery,
  incredibly restrained type. Property comes through as a *place* before it
  comes through as an inventory item. Color palette: deep forest green,
  bone, brass accent.
- **Steal:** the parallax depth ratio (background photo moves slower than
  foreground type). In SwiftUI, achievable with `GeometryReader` + a
  `scrollPosition` driven `offset` modifier.

### 1.4 Travel Next Level — Awwwards SOTD + Developer Award, December 2024
- URL: <https://www.awwwards.com/sites/travel-next-level>
- Designer: Artemii Lebedev
- **What stands out:** Editorial layout meets motion. Cards stack with
  z-axis tilt (~6° y-axis rotation), revealing the next card behind on
  hover. Heavy serif display, brutalist-adjacent metadata.
- **Steal:** the tilt-on-stack pattern. SwiftUI: `rotation3DEffect`
  with a `(x: 0, y: 1, z: 0)` axis driven by drag offset. Looks expensive,
  is one modifier.

### 1.5 Here & Away — Awwwards Hotel/Restaurant nominee
- URL: <https://www.awwwards.com/sites/here-away>
- Designer: Duo Studio
- **What stands out:** Magazine-style spreads. Big serif headlines, generous
  whitespace, photography cropped tight on architectural details rather than
  wide hotel exteriors. The shift from "marketing wide-shot" to "editorial
  detail-shot" is the entire mood.
- **Steal:** the photography crop philosophy. This isn't code — it's a
  brief for whoever sources imagery. Ban hero exteriors; require detail
  crops (a doorway, a tap, a single bed corner with morning light).

### 1.6 Snami Travel — Awwwards Honorable Mention, November 2025
- URL: <https://www.awwwards.com/sites/snami-travel>
- Designer: Lime Creative
- **What stands out:** Ultra-warm palette (cream, terracotta, ochre).
  Cards have visible paper grain texture as background. Type uses a single
  display family with massive size variance — 64pt headlines next to 11pt
  metadata, no middle weights.
- **Steal:** the size-jump hierarchy (skip the 18-24pt zone entirely).
  Confidence-by-omission. Easy in SwiftUI — just don't define a body+1
  text style.

### 1.7 Spain Collection Travel — Awwwards Honorable Mention, October 2025
- URL: <https://www.awwwards.com/sites/spain-collection-travel>
- Designer: Dgrees
- **What stands out:** Image-first listing with a single accent color
  (clay red) used only for one element per card — sometimes a price tag,
  sometimes a "favorite" heart, never both. Disciplined accent-as-exception.
- **Steal:** the one-color-one-element rule. Maps directly to "use
  `.tint(.red)` exactly once per card view."

### 1.8 Trippy — Hotel Booking App UX/UI Case Study (Behance, Feb 2026)
- URL: <https://www.behance.net/gallery/218422087/Trippy-Hotel-Booking-App-UX-UI-Case-Study>
- **What stands out:** Big rounded-corner cards (24pt+ radius) with image
  occupying ~70% of card height, type stack pinned to bottom. Subtle
  multi-layer shadow underneath card creates "floating" feel. Cards
  themselves are warm white on a slightly cooler page background — a
  trick that costs nothing and reads as quality.
- **Steal:** the page-bg-cooler-than-card-bg trick. `Color(hex: "#F4F2EE")`
  page, `Color(hex: "#FBFAF7")` card. The 1-2 step lift in lightness reads
  as elevation more cleanly than any shadow.

### 1.9 Otella — Hotel Booking App Case Study (Behance)
- URL: <https://www.behance.net/gallery/242750035/Otella-Hotel-Booking-App-UI-UX-Case-Study>
- **What stands out:** Photography masked into asymmetric shapes — not just
  rounded rectangles, but rectangles with one aggressively rounded corner
  and three sharp corners. Creates a visual signature without a logo.
- **Steal:** the asymmetric corner radius. SwiftUI has
  `UnevenRoundedRectangle(cornerRadii: .init(topLeading: 32, bottomLeading: 4,
  bottomTrailing: 4, topTrailing: 4))` since iOS 16. Underused.

### 1.10 Wego — Flight & Hotel Booking App Redesign (Behance)
- URL: <https://www.behance.net/gallery/234209543/Wego-Flight-Hotel-Booking-App-Redesign>
- **What stands out:** Less editorial than the rest, but high engagement
  (1k+ appreciations). Worth studying for the *commercial* card pattern:
  thumbnail left, title + rating + price stack right, single CTA. The
  baseline we are pushing past.

### 1.11 Travel App Concept — Risang Kuncoro / Plainthing Studio
- URL: <https://dribbble.com/shots/15079032-Travel-App-Concept>
- **What stands out:** Plainthing's signature illustration accents inside
  an otherwise photo-led layout. Small custom icon set (~20pt) drawn in
  the same line weight as the type's stem — feels custom rather than
  bolted-on.
- **Steal:** the line-weight-matching for icons. If your type has a
  ~1.5pt stem, your icons should too. SF Symbols at `.thin` weight gets
  you most of the way; for more character, swap to a custom set.

### 1.12 Travel Booking Mobile Apps — Fauzi Akmal / Plainthing Studio
- URL: <https://dribbble.com/shots/14896063-Travel-Booking-Mobile-Apps>
- **What stands out:** Vertical list of large cards. Each card shows the
  property photo bleeding past card edge into the page margin on one side —
  a "torn page" effect. Photos extend ~12pt past the right edge of the
  card surface.
- **Steal:** the bleed. SwiftUI: `Image` with `.frame(width: cardWidth + 24)`
  inside a `clipped()` parent. Or, more cleanly, an
  `overlay(alignment: .trailing)` with a horizontally over-sized image.

### 1.13 Travel Service App Design — Syafrini Nabilla / Plainthing Studio
- URL: <https://dribbble.com/shots/15901358-Travel-Service-App-Design>
- **What stands out:** Pill-shaped category chips at the top of the screen,
  but the active chip uses an inverted color treatment (dark bg + light
  text) and a subtle inner shadow that reads as "pressed." Inactive chips
  are flat.
- **Steal:** the pressed-state inner shadow. iOS 16+ has
  `.shadow(.inner(color:radius:x:y:))` natively.

### 1.14 Hotel Booking App UI — Glassmorphism + Interactive Map (Dribbble, 2025)
- URL: <https://dribbble.com/shots/26331938-Hotel-Booking-App-UI-Glassmorphism-Interactive-Map-2025>
- **What stands out:** Map-first listing. Hotel cards float as glass panels
  *over* the map. The glass treatment uses heavy blur (~30pt) plus a 1pt
  hairline at 20% white. Backplate gradient is a warm-to-cool sunset.
- **Steal:** the map-floating glass pattern. SwiftUI: `Map` background,
  `.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))`
  for the floating card. Comes free, looks expensive.

### 1.15 Bubble — Mobile App Design (Outcrowd, Dribbble)
- URL: <https://dribbble.com/shots/15902223-Bubble-Mobile-App-Design>
- **What stands out:** Outcrowd's house style — thick rounded shapes,
  high-saturation accent colors, custom illustration. Not a hotel app, but
  the *card-in-card* nesting pattern (a small status pill nested over the
  corner of a hero card) is the most-copied detail in their portfolio.
- **Steal:** the nested-pill pattern. ZStack alignment + small offset.

---

## 2. Recurring DEPTH techniques

After tagging the 15 references above plus another ~30 honorable-mention
shots, the depth playbook converges on six moves. Listed in rough order
of frequency in the strongest editorial work:

### 2.1 Layered photography bleed
Image extends past the card's bounding rectangle on one or two sides.
Not a full bleed (that would be an image-only screen) — a deliberate
12-24pt overhang that reads as "this card is too big to contain its
contents." Strongly editorial. Common in print magazines as a "gutter
break." Almost no production booking app uses this; pure Dribbble move
for now.

### 2.2 Multiple soft drop shadows
Single shadows look like Material Design from 2017. The current move is
two or three stacked shadows at increasing radii and decreasing opacity:
- Inner: `0 1px 2px rgba(0,0,0,0.04)` — anchors the bottom edge
- Mid: `0 4px 12px rgba(0,0,0,0.06)` — gives the float feel
- Outer: `0 24px 48px rgba(0,0,0,0.04)` — establishes scene depth

In SwiftUI, this is just three `.shadow()` modifiers chained. Costs
nothing but reads as rendered-in-Cinema-4D vs rendered-in-Figma.

### 2.3 Cool page / warm card lift
Page background is one notch cooler and one notch darker than the card
surface. Eliminates the need for a heavy border or shadow because the
contrast itself reads as elevation. The Trippy and Tribe Stays references
both use this. Often paired with a barely-perceptible 1px hairline at the
card edge.

### 2.4 Glassmorphism over photography or maps
Strong when there is a **photographic background** to refract. Weak on
solid-color screens (looks dated). The 2025 Dribbble map-overlay shot is
the canonical use. Backdrop blur + low-opacity tint + 1px hairline. Apple
Materials in SwiftUI gives you this for free with `ultraThinMaterial` /
`thinMaterial` / `regularMaterial`.

### 2.5 Asymmetric corner radii
Same principle as a torn page or a deckle-edge. One corner sharply
rounded (24-40pt), the other three minimally so (4-8pt). Creates a
direction without an arrow. iOS 16+ has `UnevenRoundedRectangle` natively.

### 2.6 Subtle 3D rotation on stacks
The Travel Next Level reference uses ~6° y-axis tilt for cards in a
deck. The Snami carousel uses a similar move. Trick: keep the rotation
*small* — 3-8°. Larger angles look like a coverflow gimmick.
`rotation3DEffect((axis: (x: 0, y: 1, z: 0)), perspective: 0.4)` in
SwiftUI.

What you almost never see in the best work: heavy neumorphism (it dates
fast), gradient-filled card backgrounds (they fight photography), or
deeply colored shadows (they read as 2014 Material Design).

---

## 3. Recurring CHARACTER techniques

The depth moves give you the floor. Character is what wins the shot.
Patterns that surface repeatedly in award-winning hospitality work:

### 3.1 Serif + sans pairing, no third family
The single move that does the most. A high-contrast display serif
(Canela, Tiempos Headline, GT Sectra, Editorial New, Recoleta, PP Editorial,
Söhne Mono for technical accents) for property names; a precise grotesque
(Söhne, Inter, GT America, Neue Haas Grotesk, SF Pro for Apple-native) for
all metadata. The serif is *only* used at large sizes — never below ~22pt.
The sans is *only* used at small-to-medium — never above ~28pt. The size
boundary becomes a perceptual signal that says "you are reading the title"
vs "you are reading data."

For a SwiftUI app, you can ship this with:
- Display: a free editorial serif from Google Fonts (Cormorant, Fraunces,
  DM Serif Display) registered via `Info.plist`'s `UIAppFonts`.
- Body: SF Pro (default, free, world-class).

### 3.2 Custom or pseudo-custom icons
Either bespoke line-art glyphs (Plainthing's house style) or SF Symbols
restyled with a non-default weight + a specific accent color used nowhere
else in the UI. The point is that icons become a brand element rather than
a system element. Easy lift: pick `.thin` or `.ultraLight` SF Symbols and
commit to it everywhere.

### 3.3 Photography crops biased to architectural detail
The single largest mood lever. Hero shots of a hotel exterior read as
"booking site." Detail crops of textures, doorways, food plates, light
falling on linen, read as "magazine." None of this is design code — it's
a photo brief. But it disqualifies most stock libraries.

### 3.4 Branded color systems with a single accent
Two to three neutrals + one accent. Not five colors. Not a "design system
palette." Three. The accent appears with the discipline of an alarm —
on price, on a single CTA, never decoratively. (See Hedwig, Spain
Collection, Snami.)

### 3.5 Number-as-headline treatment
Prices, ratings, and dates set in the display serif at headline scale,
not in the metadata sans. Treating a number as a typographic hero element
is a strong editorial signal — magazines do it constantly ("$2,400 a
night," "9 hours of sleep," "1932"). Trivial in SwiftUI: just route
prices through your display style instead of your body style.

### 3.6 Whitespace as composition
The strongest work allocates 40-60% of the visible area to negative
space, not content. Snami and Hedwig both bias to this. The composition
*is* the spacing. This is an act of discipline more than an act of code.

### 3.7 Single-photo-per-screen restraint
Several award shots show only **one** hotel image per screen — even on
listings — relying on swipe to advance. The vertical feed pattern we
know from Instagram Stories, applied to inventory. A rejection of the
density bias of conventional booking apps. High risk for a real product
because it kills SKU density, but worth knowing.

---

## 4. Top 5 stealable patterns for a SwiftUI hotel card

Five patterns that are (a) high-character, (b) achievable in stock SwiftUI
inside a five-day timeline, and (c) different enough from the genre baseline
to feel intentional.

### Pattern A — "Plate-on-photo" hotel card
- Vertical card, 3:4 photo, dark-tinted color plate (cream, rust, or ink)
  docked to the bottom-leading corner with a small offset.
- Plate carries the property name in display serif + city in sans caps.
- Price either omitted from the card or set in the display serif as a
  single inline number with no currency word.
- SwiftUI:
  ```swift
  ZStack(alignment: .bottomLeading) {
      Image("hotel-1").resizable().aspectRatio(3/4, contentMode: .fill)
      VStack(alignment: .leading, spacing: 4) {
          Text("Casa Mira").font(.custom("Fraunces-Regular", size: 22))
          Text("OAXACA").font(.system(size: 11, weight: .medium))
              .tracking(2).foregroundStyle(.secondary)
      }
      .padding(16)
      .background(Color("PlateCream"))
      .offset(x: -12, y: 12)
  }
  .clipShape(UnevenRoundedRectangle(cornerRadii: .init(
      topLeading: 4, bottomLeading: 4, bottomTrailing: 4, topTrailing: 32
  )))
  ```

### Pattern B — "Cool page, warm card" elevation
- Page background ~2-3% darker and cooler than card surface.
- 1pt hairline at ~6% ink, three stacked shadows (see §2.2).
- No heavy borders. No gradient fills. Just paper-on-paper feel.
- SwiftUI:
  ```swift
  card
      .background(Color("CardSurface"), in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12)
          .stroke(.black.opacity(0.06), lineWidth: 1))
      .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
      .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
      .shadow(color: .black.opacity(0.04), radius: 48, y: 24)
  ```

### Pattern C — "Editorial deck" card stack
- Three-card stack with the back cards rotated ~5° on y-axis and offset
  by 8pt y, scaled to 0.95.
- Front card is fully interactive; back cards are decorative.
- On drag, front card translates and the deck progresses.
- SwiftUI: `ZStack` + `rotation3DEffect` + `scaleEffect` + `gesture`.
- Visually unmistakable as "your inventory is curated, not paginated."

### Pattern D — "Hairline-only" listing
- No card chrome at all — only a photograph + a 1pt hairline + a caption
  block of property name (display serif) over city + nightly rate (sans
  caps).
- Vertical list of these reads exactly like a Kinfolk-style print spread.
- SwiftUI: just a `LazyVStack` of `VStack` containing `Image`, `Divider`
  with custom color, then text. Almost no styling.
- Hardest part is *not* adding things.

### Pattern E — "Map-floating glass" overlay
- For the search/results screen: a `Map` view full-screen, with hotel
  cards as `ultraThinMaterial` panels floating in a horizontal scroller
  along the bottom.
- Each glass card carries a small thumbnail + property name + price.
- Tapping snaps both the carousel and the map to that pin.
- Glass works here because the *map* provides the photographic
  background that glass needs to refract.

---

## 5. SwiftUI feasibility notes per pattern

A reality check on which Dribbble moves you can ship vs which require
custom rendering, custom shaders, or quietly faking it.

| Effect | iOS native? | Notes |
|--------|-------------|-------|
| Multi-layer drop shadow | Yes | Chain `.shadow()` modifiers. Free. |
| `ultraThinMaterial` glass | Yes | iOS 15+. Only looks good over photo/map. |
| Mesh gradient backplate | Yes (iOS 18+) | `MeshGradient` API. Drop-in for hero backgrounds. |
| Inner shadow | Yes (iOS 16+) | `.shadow(.inner(...))`. Pressed-state look. |
| Asymmetric corner radius | Yes (iOS 16+) | `UnevenRoundedRectangle`. Underused. |
| 3D rotation / tilt | Yes | `rotation3DEffect`. Keep angles small (<10°). |
| Parallax on scroll | Yes | `GeometryReader` + scroll offset → image y-offset. Or `scrollTransition` (iOS 17+). |
| Image bleed past card | Yes | `frame` larger than parent + parent `.clipped()`. |
| Variable / progressive blur | **Hard** | Needs Metal shader (`.layerEffect(...)`) or a third-party lib like Variablur. iOS 17+ only. |
| Custom typography pairing | Yes | Register OTF/TTF via `Info.plist` `UIAppFonts`. |
| Paper grain texture | Yes-ish | `.background(Image("grain").resizable(resizingMode: .tile))` blended at low opacity. Works. |
| Color noise / dithering on gradients | Hard | Needs Metal shader. `Inferno` library (twostraws) gives you a starter set. |
| Parallax on device tilt | Yes | Core Motion + `offset`. Use sparingly — most apps over-do it. |
| Editorial-grade kerning | Yes | `.tracking()` and `.kerning()` modifiers. Don't forget `.lineSpacing()` for body. |
| Page-curl / coverflow | **No** in stock SwiftUI | Falls into UIKit + private animation territory. Don't go here for a 5-day timeline. |
| Heavy custom illustration | Manual | You're shipping SVG/PNG assets. Not a SwiftUI problem; a brief problem. |

The pragmatic stack for a five-day editorial hotel card: stock SwiftUI
+ one custom font family + maybe `MeshGradient` for one hero backdrop.
That covers ~85% of the visual moves catalogued above. Skip Metal
shaders unless you have a specific must-have effect; the time cost is
disproportionate to the visual delta.

---

## 6. Color palette inspiration

The best luxury-hospitality work in the survey converges on a tight
palette family. Aman, Six Senses, Rosewood, Ace, and the editorial
Dribbble work all sit in roughly the same color territory: warm
neutrals, one earth accent, one ink. Cool palettes (steel-blue,
slate-green) appear, but mostly for properties branded around water
or alpine settings.

### Palette 1 — "Aman / linen + ink" (the safe luxury default)
- Bg: `#F5F1EA` (warm bone)
- Card: `#FBFAF6` (paper white)
- Ink: `#1F1B16` (warm near-black)
- Secondary text: `#6B6358` (warm gray)
- Accent: `#7A6048` (single warm bronze, used 1x per screen)

Reads like Aman, Six Senses, Soho House. Photographs well. Almost
impossible to make ugly.

### Palette 2 — "Rosewood / clay + cream"
- Bg: `#EFE7DA` (cream)
- Card: `#FFFFFF`
- Ink: `#2A1F18` (espresso)
- Accent: `#B05B3F` (terracotta — used on price and one CTA)
- Detail: `#3F4A35` (deep olive — used only in icons)

Warmer, more confident, more distinctive. Strong with photography
that contains warm tones (sunset, wood, food). Risky with cool
photography (snow, ocean).

### Palette 3 — "Ace / brutalist warm"
- Bg: `#E8E3DA` (sand)
- Card: `#1F1B17` (ink)
- Card text: `#F5F1EA` (bone)
- Accent: `#D9533C` (dark vermilion)
- Detail: `#A89F8E` (warm gray)

Inverted card on warm page. Editorial, distinctive, harder to scale —
photography needs to be *very* good because it's surrounded by darkness.
Strong for premium/curated tiers; dangerous for full inventory.

### Palette 4 — "Belmond / coastal + brass"
- Bg: `#EAE6DD` (oat)
- Card: `#FFFFFF`
- Ink: `#142826` (deep teal-black)
- Accent: `#A57E3F` (brass — used on price + favorite)
- Detail: `#5B7773` (eucalyptus, only in iconography)

Best for properties with water/coastal photography. The brass + deep
teal pair photographs like a Belmond brochure.

### Palette 5 — "Six Senses / forest + earth"
- Bg: `#F2EFE6` (chamomile)
- Card: `#FBFAF5`
- Ink: `#1A2618` (forest near-black)
- Accent: `#3B5C3A` (forest green)
- Detail: `#8C6F4F` (warm taupe)

Nature-led palette. Pairs beautifully with detail photography of
plants, wood, stone.

### What to avoid
- Pure white (`#FFFFFF`) page backgrounds. Reads as enterprise SaaS.
- Pure black (`#000000`) ink. Reads as harsh on a warm field; use
  `#1A1A1A` to `#221F1A` instead.
- Cool gray (`#888888` family) secondary text on a warm bg. Color-
  temperature mismatches kill the editorial feel faster than anything.
  Match the gray's temperature to the bg's temperature.
- Multi-color accent systems. Pick one accent. Use it sparingly. The
  "calm field, single alarm" principle from Apple's HIG applies double
  to editorial work.
- Photoshop drop shadows with high opacity (>15%). Layer multiple low-
  opacity shadows instead.

---

## 7. Cross-cutting observations

Three meta-observations from the survey worth sitting with:

**Editorial work is mostly subtraction.** The 15 references above are
not technically more elaborate than a typical Booking.com card — most
are *less* technically elaborate. They look more sophisticated because
they have removed: badges, ratings stars, wishlist hearts, "deal!"
chips, second-tier metadata, and most colors. A SwiftUI hotel card
with one `Image`, two `Text`, and a `Divider` will out-class a card
with eight subviews if the typography and crop are right.

**Photography is the design.** Unanimously, across every strong shot,
the difference between editorial and "Trip Advisor 2014" is the
photograph. No amount of shadow stacking, mesh gradient, or custom
type rescues a generic stock exterior. This is partly a brief problem
(write a tight photo brief, ban hero exteriors), partly an MVP problem
(seed the demo with a curated set of 6-12 hand-picked properties
rather than a database dump of 600).

**Depth ≠ literal 3D.** None of the strongest references use
skeuomorphic depth (no leather textures, no polished glass beads, no
neumorphism). The depth they read with is the depth of *paper* —
soft, flat, layered. This is achievable in SwiftUI with the simplest
primitives in the framework. You do not need shaders.

---

## 8. Direct reference index

Quick-grab list of the URLs used above.

**Awwwards:**
- <https://www.awwwards.com/sites/hedwig-curated-travel>
- <https://www.awwwards.com/sites/tribe-stays>
- <https://www.awwwards.com/sites/explore-primland>
- <https://www.awwwards.com/sites/travel-next-level>
- <https://www.awwwards.com/sites/here-away>
- <https://www.awwwards.com/sites/snami-travel>
- <https://www.awwwards.com/sites/spain-collection-travel>
- <https://www.awwwards.com/websites/hotel-restaurant/>
- <https://www.awwwards.com/websites/travel-tourism/>

**Behance:**
- <https://www.behance.net/gallery/218422087/Trippy-Hotel-Booking-App-UX-UI-Case-Study>
- <https://www.behance.net/gallery/242750035/Otella-Hotel-Booking-App-UI-UX-Case-Study>
- <https://www.behance.net/gallery/234209543/Wego-Flight-Hotel-Booking-App-Redesign>

**Dribbble:**
- <https://dribbble.com/shots/15079032-Travel-App-Concept> (Plainthing / Risang Kuncoro)
- <https://dribbble.com/shots/14896063-Travel-Booking-Mobile-Apps> (Plainthing / Fauzi Akmal)
- <https://dribbble.com/shots/15901358-Travel-Service-App-Design> (Plainthing / Syafrini Nabilla)
- <https://dribbble.com/shots/26331938-Hotel-Booking-App-UI-Glassmorphism-Interactive-Map-2025>
- <https://dribbble.com/shots/15902223-Bubble-Mobile-App-Design> (Outcrowd)
- <https://dribbble.com/plainthingstudio>
- <https://dribbble.com/cuberto>
- <https://dribbble.com/halolab>
- <https://dribbble.com/tags/hotel-booking-app>
- <https://dribbble.com/search/luxury-hotel-app>

**Industry references:**
- Aman brand identity (Construct): <https://bpando.org/2016/02/16/branding-aman/>
- Aman identity expansion (Colville-Walker): <https://colville-walker.com/work/aman-branding-identity-development-and-expansion>
- Airbnb 2025 redesign coverage (It's Nice That): <https://www.itsnicethat.com/articles/airbnb-app-redesign-140525>
- Airbnb redesign (Design Week): <https://www.designweek.co.uk/it-was-a-bit-nuts-teo-connor-on-designing-the-new-airbnb-app/>

**SwiftUI implementation references:**
- Mesh gradients (Donny Wals): <https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/>
- WWDC24 Custom visual effects: <https://developer.apple.com/videos/play/wwdc2024/10151/>
- Inner shadow + Core Motion (Hacking with Swift): <https://www.hackingwithswift.com/articles/253/how-to-use-inner-shadows-to-simulate-depth-with-swiftui-and-core-motion>
- Inferno Metal shaders (Paul Hudson): <https://github.com/twostraws/Inferno>
- Variablur (variable blur for SwiftUI): <https://github.com/daprice/Variablur>

---

## 9. Recommended first build

If we have to pick one direction for the v1 hotel card based on this
survey, the recommendation is:

> **Pattern D** (hairline-only listing) for the **list/feed** screen,
> and **Pattern A** (plate-on-photo) for the **featured / curated**
> shelf at the top of the feed. Color palette 1 (Aman / linen + ink)
> as the safe default, with palette 2 (Rosewood / clay + cream) as a
> stretch target if the photography supports it.

That combo gives us:
- Editorial mood from line one of the brief.
- Trivially achievable in stock SwiftUI inside the timeline.
- Distinctive enough to read as not-Booking.com without inventing
  anything that doesn't already ship in the Cocoa stack.
- A coherent rationale we can explain to the interview panel: every
  decision points back to a specific reference in the survey above.

The risks to flag in the README: photography quality is the binding
constraint, and the "no chrome / no badges" approach kills space we'd
normally spend on review counts, deal flags, etc. Those are intentional
omissions, but worth defending in the case study writeup.
