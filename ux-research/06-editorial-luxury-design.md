# Editorial / Luxury Hospitality Design Patterns

A reference for the visual vocabulary used by Mr & Mrs Smith, Aman, One Hotels, Soho House, and Edition. These apps share a posture: they assume the user has time, taste, and attention. They do not compete for the eye — they compose for it. This document is intended to feed concrete decisions for the ResortPass take-home: what type to use, how much air to leave around it, how flat the layout can be before it stops feeling like a product, and which SwiftUI primitives get us there without a custom font dependency.

## 1. Typography Choices

The defining move in luxury hospitality apps is the serif headline. Mr & Mrs Smith, Edition, and the NYT-style editorial apps all run a serif at the title position and a sans at the supporting position. The serif communicates two things at once: heritage (typography that predates the iPhone by 200 years) and editorial authority (this is content worth reading, not a row in a database). The sans handles everything that needs to be scanned — prices, ratings, distance, dates — because sans is faster to parse at small sizes.

The pairing pattern is consistent across the reference set:

- **Mr & Mrs Smith** — A modern transitional serif (close to GT Sectra / Tiempos) for hotel names and editorial headlines, paired with a humanist sans for body and metadata. The serif is set tight, often `-0.02em` letter-spacing, and used at large sizes (28-40px on hotel detail).
- **Aman** — Almost entirely a single serif (a custom face close to Optima/Trajan in feel — narrow, high-contrast, ALL CAPS for the wordmark, mixed case for body). The sans is reserved for legal/utility text. Aman trusts the serif to do everything.
- **Edition Hotels** — A geometric sans wordmark paired with a transitional serif for property names. They invert the expected balance: the brand is sans (modern), the properties are serif (storied).
- **One Hotels** — A grotesque sans throughout (close to Founders Grotesk), but with an almost-serif weight discipline: most text is set in light or regular, and medium is the heaviest weight that ever appears. The luxury cue here is not the serif — it's the refusal to bold.
- **Soho House** — A classic serif (close to Caslon/Miller) for editorial headlines in the member area, sans for navigation and forms. The serif appears specifically in the "House Notes" / editorial content, never in transactional flows.

**The pairing rule:** serif for *names* (proper nouns, headlines, things that should be read slowly), sans for *data* (numbers, labels, things that should be scanned). Never mix two serifs. Never mix two sans-serifs in the same role.

### iOS native equivalents

You do not need to ship a custom font to get this look on iOS. The system gives you:

- **`.serif` design on SF** — `Font.system(.title, design: .serif)` returns **New York**, Apple's transitional serif designed specifically to pair with SF Pro. It has the same metrics and optical sizing system as SF, so the rhythm holds when you mix them. New York at large display sizes (28-40px) reads close to GT Sectra — high contrast strokes, refined terminals, slightly condensed.
- **Charter** — Available system-wide as `"Charter"` (`Font.custom("Charter", size: 17)`). Designed by Matthew Carter for low-resolution screens, it has a more "magazine reading" quality than New York — wider proportions, more generous counters. Better for body copy than display.
- **New York via design parameter** — Always prefer `.system(..., design: .serif)` over `Font.custom("New York", ...)` because the design parameter respects Dynamic Type and optical sizing automatically.
- **SF Pro Display vs SF Pro Text** — The system handles the switch automatically based on size when you use `Font.system(...)`. Display variant is used at 20pt+, with tighter spacing and refined terminals.

For the take-home, the entire type system can be:

```swift
enum AppFont {
    static func displaySerif(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static func bodySans(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func labelSans(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}
```

No custom font registration. No `Info.plist` changes. No license question.

## 2. Whitespace Discipline

Luxury apps treat whitespace as a primary material, not a residue. The rule across the reference set:

- **Outer gutters** are 24-32pt on phone, often 48pt+ on tablet. Mass-market apps run 16pt. The 8-16pt difference reads at a glance — the page feels "bigger" without being any taller.
- **Vertical rhythm between sections** is at least 2x the rhythm within a section. If headline and subhead are 8pt apart, the next section starts 32pt away. This creates implicit grouping without dividers.
- **Content max-width** is enforced even on phone, but this matters more on tablet and landscape. Aman caps text columns at roughly 600pt even on a 1024pt-wide iPad. Mr & Mrs Smith does the same.
- **Line-height** is generous — 1.5-1.7x for body. Cramped line-height (1.2-1.3x) is a tell of a content-dense app (news, social) and is avoided in luxury contexts.
- **Image-to-text spacing** is wider than text-to-text spacing. A photo above a caption typically has 16-20pt below it before the caption — the caption belongs to the photo, but the photo "owns" the space.

The pattern: leave enough air that the user feels the design is unhurried. Cramped layouts feel like they're trying to sell. Open layouts feel like they're presenting.

## 3. Color Palette Restraint

Every reference app runs on 2-3 colors. That's it.

- **Aman** — Cream `#F4EFE6`, deep charcoal `#1A1A1A`, and a single warm taupe accent `#A89580`. No other color appears anywhere in the app.
- **Mr & Mrs Smith** — Off-white background `#FAF8F5`, near-black text `#1C1C1C`, deep terracotta accent `#C04B30` for CTAs and the wordmark. Photos carry all other color.
- **Edition** — Pure white `#FFFFFF`, near-black `#000000`, and gold/brass `#B8935A` used only on the wordmark and key CTAs.
- **One Hotels** — Sage green `#5C6B5A`, warm white `#F5F2ED`, and a darker forest green for emphasis. The entire palette is drawn from the brand's natural-materials positioning.
- **Soho House** — Cream `#F4F1EA`, brand pink `#E8A4A0` (used very sparingly), near-black text. The pink is reserved for member-only states.

**The discipline:** define one neutral background, one near-black for text, and one accent — and the accent is used only for interactive affordances and brand moments. Photos carry the chromatic load. The chrome is monochromatic so the photography reads as the content.

For ResortPass, this maps cleanly to Asset Catalog:

- `BackgroundPrimary` — `#FAF8F5` (warm off-white) light / `#0F0E0C` (warm charcoal) dark
- `BackgroundElevated` — `#FFFFFF` light / `#1A1815` dark
- `TextPrimary` — `#1C1C1C` light / `#F0EDE8` dark
- `TextSecondary` — `#6B6560` light / `#8A8580` dark
- `Accent` — single color, semantic, used only on CTAs and selected states

Two notes: (1) define these in the Asset Catalog with light/dark variants, never hardcode in views; (2) avoid pure white and pure black. The 2-5% warm tint reads as "considered" rather than "default."

## 4. Image-as-Hero Treatment

Luxury hospitality apps are photo-first. The image is not decoration — it is the primary content. The chrome around the image is reduced to nothing or near-nothing.

The pattern:

- **Aspect ratios are editorial.** 3:2 or 4:5, not 16:9. The taller crop signals "this was composed by a photographer," not "this came out of a CMS."
- **Images bleed.** They go edge-to-edge of the card or even edge-to-edge of the screen. Inset images with margins read as web circa 2014.
- **No overlay chrome on the image itself.** No price chip, no rating badge, no "Book Now" button floating on the photo. The photo is sacred. All metadata lives below it, in a separate visual zone.
- **Single hero, not carousel-by-default.** Mr & Mrs Smith and Aman both default to a single hero image with a tap-to-expand gallery. Carousels with dots feel marketplace-y.
- **Black-and-white or low-saturation when the brand calls for it.** Soho House uses a lot of B&W editorial photography. The chromatic restraint of the chrome lets the photography breathe even when it's color.

The implementation move: the image is the structural element. Type below it is small relative to the image — the image is 250-400pt tall and the title is 24pt. The size ratio is what makes the image dominant; you don't need a frame around it.

## 5. Hierarchy Through Weight, Not Size

Mass-market apps create hierarchy by jumping size: 32pt headline, 14pt body. Luxury apps create hierarchy by jumping weight at similar sizes.

Common pattern:

- Hotel name: 22pt serif, regular weight
- Location: 14pt sans, regular weight
- Rating: 14pt sans, medium weight
- Price: 16pt sans, medium weight

The size range is compressed (14-22pt across the whole card), and what differentiates each role is the *weight* and the *design family* (serif vs sans). This reads more refined because the visual jumps are small — your eye glides through the hierarchy rather than cliff-diving down it.

The rule of thumb borrowed from Vercel's Geist and the editorial print tradition: **two weights, max.** Light/regular as the base, medium as the emphasis. Bold (`.bold` or weight 700) is reserved for genuinely critical information — typically just the price at the moment of decision, or never.

The exception is the serif headline at very large sizes (40pt+), which can run regular weight and still feel like a headline because the serif itself carries weight at that size. This is why luxury apps can have a "title" that is just `.serif`/regular — the typeface does what bold would do in a sans context.

## 6. Negative Space as Confidence

Cramped layouts feel desperate. Luxury layouts feel certain. This translates to specific spacing decisions:

- **Section spacing is deliberately uncomfortable.** 64-80pt between major sections on phone. The user has to scroll past empty space — and the empty space is the message: "we are not panicking to fill your screen."
- **Hero-to-content gap is large.** The image ends, and the title doesn't appear immediately. There's a 24-32pt breath. The image is allowed to land before the type starts.
- **Single-column, even when multi-column would fit.** Aman's hotel detail page is a single column even on iPad. Density is a mass-market value, not a luxury one.
- **Less per screen, more screens.** Luxury apps assume scrolling. They put 2-3 hotels in the viewport, not 5. The user scrolls leisurely, looking, not hunting.

The opposite anti-pattern: a screen with a header, sticky filter bar, dense grid, footer nav, FAB, and toast notification visible at once. Every one of those elements is the app saying "I am worried you'll leave." Luxury says "stay as long as you like."

## 7. Card vs Flat Layouts

Most modern apps reach for cards by default — rounded corners, shadows, borders, a slightly elevated background. Luxury apps usually reject this entirely.

The flat pattern:

- **No card chrome.** The image goes straight on the page background. The title sits below the image with the same horizontal padding as the rest of the content. There is no container.
- **Spacing defines grouping.** The "card" is implied by the proximity of the image and its caption — they sit together in a 16-20pt cluster, with 48-64pt between clusters. You read the structure without any borders or backgrounds telling you it's a unit.
- **Dividers are rare.** When they appear, they're hairlines (`#E5E1DB` on cream, `0.5pt`), not the standard `#E5E5E5` 1pt rule. Often there's no divider at all — whitespace does the work.
- **Rounded corners only on images themselves.** And often only 4-8pt — slight, not bubbly. Aman uses square corners on photography. Mr & Mrs Smith uses 4pt. Edition uses none.

When luxury apps do use cards, they use them sparingly and with very low chrome: subtle elevation (a near-invisible shadow), no visible border, generous internal padding (24pt+).

For a take-home, the flat treatment is cheaper to implement (no shadow tuning, no border color decisions) and reads as more sophisticated. Choose flat by default.

## 8. Specific Reference Notes

**Mr & Mrs Smith — Hotel Detail Page**
- Hero image at full viewport width, ~60% of the screen height on phone
- Hotel name in large serif (32-36pt), regular weight, set on a single line where possible
- Location below in 14pt sans, secondary text color, with a tiny pin icon
- Star rating not as five stars, but as a number ("8.7") — minimal visual noise
- Editorial copy in serif body (16pt, 1.6x line-height), 90-100 character line length
- Price and "Book" CTA appear only at the bottom of the page, never floating

**Aman — Minimal Nav, Large Photography**
- Tab bar is barely visible — translucent background, single-color icons, no labels
- Wordmark in the top center, never a hamburger or back chevron when avoidable
- Property pages are entirely image-driven. Long vertical scrolls of full-width photography with sparse type interleaved
- The "book" affordance is intentionally hard to find — Aman's stance is that you call to reserve

**One Hotels — Typography + Booking Flow**
- Serif-free, but the sans is used at light/regular weights almost exclusively
- Booking flow uses lots of vertical space per step — one decision per screen
- Date pickers and selectors have generous tap targets (60pt+ height) with thin dividers
- Brand color (sage green) is used as a thin underline on selected dates, not as a fill

**Soho House — Editorial Member Area**
- Member dashboard reads like a magazine table of contents: serif title, sans byline, image
- "House Notes" content uses traditional editorial layout — drop caps, pull quotes, generous margins
- The membership card is treated as an artifact: a single screen, mostly empty, with the member's name in serif and the house name below

## 9. iOS Native Treatments That Feel Luxury

The take-home opportunity is that iOS gives you the entire luxury toolkit without third-party dependencies:

- **`.system(..., design: .serif)`** — New York. The single most important tool. Use it for hotel names and any time you'd reach for a custom serif.
- **Asset Catalog colors with off-white tones** — Define your background as `#FAF8F5` (warm) or `#F7F8F9` (cool), not `#FFFFFF`. The 5% tint is the entire difference between "considered" and "default."
- **`.fontWeight(.regular)` and `.fontWeight(.medium)`** — Resist `.bold` and `.semibold` everywhere except final-decision moments. Most text should be regular.
- **`.kerning(-0.5)` on serif headlines** — Tightens display-size serif type the way print designers do. Use on titles 24pt+.
- **`.lineSpacing(6)` on body text** — Adds breathing room. Combined with a 16pt body font, gives ~1.6x line-height.
- **`.tracking(0.5)` on small caps labels** — When you do use small all-caps labels (sparingly, for section headers), letter-spacing them slightly out makes them feel intentional rather than yelling.
- **Native SF Symbols at `.thin` or `.light` weight** — Mass-market apps run icons at `.regular` or `.medium`. Luxury runs them at `.thin` or `.ultralight` — the icons recede into the layout rather than competing with content.
- **`.background(Color(.systemBackground))` replaced with custom** — Don't use the system gray. Define your own warm neutral.
- **`Divider().background(...)` to soften** — Default `Divider()` is too dark. Override with `#E5E1DB` (warm) or `#EAEBED` (cool) at low opacity.

## 10. SwiftUI Recipe — Editorial Hotel Card

Concrete implementation for the ResortPass card. Flat layout, image-as-hero, serif title, sans metadata, price as inline text.

```swift
struct EditorialHotelCard: View {
    let hotel: Hotel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero image — bleeds full width of container, 4:5 aspect
            AsyncImage(url: hotel.heroImageURL) { image in
                image
                    .resizable()
                    .aspectRatio(4/5, contentMode: .fill)
            } placeholder: {
                Color(.placeholderNeutral)
                    .aspectRatio(4/5, contentMode: .fit)
            }
            .frame(maxWidth: .infinity)
            .clipped()

            // Type cluster — sits below image with deliberate breathing room
            VStack(alignment: .leading, spacing: 6) {
                Text(hotel.name)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .kerning(-0.3)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(hotel.location)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color("TextSecondary"))

                    Text("·")
                        .foregroundStyle(Color("TextSecondary"))

                    Text(hotel.rating, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("TextSecondary"))
                }

                // Price as inline text, not as a chip or pill
                Text("From \(hotel.priceFrom, format: .currency(code: "USD").precision(.fractionLength(0)))")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color("TextPrimary"))
                    .padding(.top, 8)
            }
            .padding(.top, 20)
            .padding(.horizontal, 4)  // Slight inset; not full padding
        }
        .padding(.bottom, 48)  // Section gap built into the card itself
    }
}
```

Notes on the recipe:

- The image has no rounded corners. If you want subtle ones, `.clipShape(RoundedRectangle(cornerRadius: 4))` — never more than 6pt.
- The type cluster is inset by only 4pt from the image edges. This near-alignment reads more refined than fully aligned-left text.
- Price is inline text with the prefix "From" — never a colored chip, never a pill, never a button. The price is information, not an action.
- The `padding(.bottom, 48)` is the section break. No divider needed.
- The list that contains these cards should have `.listRowSeparator(.hidden)` and `.listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))`.

For the list view itself:

```swift
ScrollView {
    LazyVStack(spacing: 0) {
        ForEach(hotels) { hotel in
            EditorialHotelCard(hotel: hotel)
                .padding(.horizontal, 24)
        }
    }
    .padding(.top, 32)
}
.background(Color("BackgroundPrimary"))
```

`LazyVStack` over `List` because `List` enforces system row chrome that fights the flat aesthetic. Lazy because we still want diffing and recycling for a long catalog.

## 11. Typography Stacks Worth Considering

System-only stacks for a take-home (no font registration, no licensing question):

**Stack A — Editorial Serif + System Sans (recommended)**
- Display & titles: `.system(..., design: .serif)` → New York
- Body: `.system(..., design: .default)` → SF Pro Text
- Numerics & labels: `.system(..., design: .default)` with `.medium` weight
- Optional: `.system(..., design: .serif)` for long-form editorial body if the design calls for it

This is the closest match to Mr & Mrs Smith / Soho House without leaving the system.

**Stack B — All Sans, Weight Discipline (One Hotels feel)**
- Display: `.system(..., design: .default)` at `.regular` weight, large size (32-40pt)
- Body: `.system(..., design: .default)` at `.regular` weight
- Labels: `.system(..., design: .default)` at `.medium`
- No serif anywhere

Cleaner, more "tech-luxury" — closer to One Hotels or Edition. Faster to ship and less risky if the rest of the app is sans-heavy.

**Stack C — Charter for Reading**
- Display: `.system(..., design: .serif)` → New York
- Editorial body: `Font.custom("Charter", size: 16)` for any long-form descriptive copy
- UI body & labels: `.system(..., design: .default)`

Charter is included in iOS but used as a custom font (no design parameter shortcut). It's optimized for body reading at small sizes — better than New York for paragraphs of 3+ sentences. Use only if you have meaningful editorial copy.

**Stack D — Display Serif via SF only**
- Everything: `.system(...)` with the design parameter switching between `.default` and `.serif`
- Use `.serif` only on hotel names and major page headlines
- Use `.default` for absolutely everything else

Simplest possible system. Probably the right answer for a take-home given time constraints — single decision per text role, zero custom font dependency, behaves correctly under Dynamic Type and dark mode automatically.

---

The through-line of all of this: luxury hospitality design is *subtractive*. Start with a normal app and remove things — borders, shadows, weights, colors, density, decoration — until what remains is photography, type, and air. The constraint that distinguishes the reference set from mass-market apps is not what they put in; it's what they had the discipline to leave out. For a take-home, this is also the cheapest path to a sophisticated look: less code, fewer assets, no font licensing, and a result that reads as considered rather than busy.
