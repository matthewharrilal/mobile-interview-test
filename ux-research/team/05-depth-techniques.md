# Depth & Dimensionality Techniques for Resort Cards

**Brief:** the cards feel flat. Survey the techniques that the 2025–2026 generation of mobile apps actually uses to give cards depth, with implementations that compile against SwiftUI on iOS 17+ and behave on a real device. Each technique below covers what it is, where it earns its keep, where it doesn't, a working recipe, and the performance and accessibility traps you only learn the hard way.

The single biggest lesson up front: **depth is never one effect.** A flat card almost never becomes a deep card by adding "a better shadow." It becomes deep by stacking three or four cheap effects so they reinforce each other — a layered shadow + a 1px highlight + a subtle gradient backplate + a tinted material. None of those alone would be visible. Together they read as a physical object.

---

## 1. Layered Shadows (Ambient + Key + Spot)

**What it is.** A real object in a real room casts more than one shadow. There's the ambient occlusion under it (very tight, very dark, very small), the soft cast shadow from the room light (medium spread, medium opacity), and the longer falloff from the dominant light source (wide spread, very low opacity). One SwiftUI `.shadow()` call gives you one of those — usually the wrong one.

**Where to use it.** Anywhere a card needs to feel lifted off the page. Especially valuable on white-on-white surfaces where a single shadow looks either too sharp (cheap drop-shadow vibe) or too blurry (greyish smear). The layered approach gives cards a physical "sitting on the table" quality.

**Where NOT to use it.** Inside a list of dozens of identical cards (perf hit accumulates). On colored or photographic backgrounds where a single softer shadow already disappears. On tightly-stacked cards with <12pt spacing — the shadows will overlap and muddy.

**Recipe.**

```swift
extension View {
    func layeredShadow(elevation: CGFloat = 1) -> some View {
        self
            // Ambient occlusion — tight, dark, no offset
            .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
            // Key shadow — medium spread, slight offset
            .shadow(color: .black.opacity(0.08), radius: 4 * elevation, x: 0, y: 2 * elevation)
            // Long shadow — wide, soft, far below
            .shadow(color: .black.opacity(0.05), radius: 16 * elevation, x: 0, y: 8 * elevation)
    }
}

// Usage
ResortCard(...)
    .background(.white, in: .rect(cornerRadius: 16))
    .layeredShadow(elevation: 1.2)
```

The `elevation` parameter scales the cast shadows but leaves the AO shadow constant — that mirrors how real shadows behave when you lift an object: the contact darkness stays, the cast spread grows.

**Performance / accessibility.**
- Each `.shadow()` is an off-screen pass. Three layered shadows on a long scrolling list of cards will tank scroll perf on older hardware. Mitigation: rasterize via `.drawingGroup()` *if* the card itself is otherwise static; don't apply `drawingGroup` if the card animates.
- On a list of >40 visible cards, drop to two layers (AO + medium key). The eye doesn't pick up the third on small surfaces anyway.
- Reduce overall opacity in dark mode by ~40%. Black shadows on near-black backgrounds are noise.

**Used well by.** Apple's App Store editorial cards, Linear's task cards on web (they backported the language to mobile), Things 3's task rows.

---

## 2. Glassmorphism — `.ultraThinMaterial`

**What it is.** A frosted blur of whatever sits behind a surface, with a hint of tint and a subtle stroke. SwiftUI ships five thicknesses: `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`, `.thickMaterial`, `.ultraThickMaterial`. Each is a real-time gaussian blur, not a static frosted texture.

**Where to use it.** Over photography. Over busy backgrounds. As a floating overlay (filter sheets, sticky search bars, bottom action bars) where you need to hide content underneath without losing the sense that it's there. Glass is also the right answer for the price pill that sits over a resort hero image — the pill becomes part of the photograph instead of a separate UI atom.

**Where NOT to use it.**
- On flat solid backgrounds — there's nothing to blur, so it just looks like a tinted rectangle and you've paid the GPU cost for nothing.
- For body content surfaces. Glass cards make great chrome and terrible content containers because text legibility drops as the background changes.
- On older devices with small screens running on battery. Materials are GPU-bound and stack poorly.

**Recipe.**

```swift
struct GlassChip<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // The "lifted glass" highlight — see technique #10
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
```

**Performance / accessibility.**
- `.ultraThinMaterial` has built-in vibrancy when used with `.foregroundStyle(.primary)` for content — text inside automatically adapts to whatever's behind. Don't override with a hardcoded color, you'll lose the adaptation.
- Test against extreme backgrounds: dark photos, light photos, motion. The `.ultraThinMaterial` thickness can become illegible over high-contrast imagery — step up to `.regularMaterial` if you're getting reports.
- Respect `Reduce Transparency` accessibility setting. SwiftUI materials honor this automatically: they fall back to a solid color. Don't bypass that with custom blur layers — you're breaking accessibility.

**Used well by.** Apple Music's now-playing sheet, Apple Maps' floating search bar, Things 3's quick-entry bar, the Halide camera app's controls.

---

## 3. Neumorphism (and why it's mostly still a trap)

**What it is.** Soft inner + outer shadows on a surface that matches the page background, suggesting an extruded or pressed shape. Big in 2020, dead by 2021, having a "2.0" moment in 2025 because the original problem (no contrast, no affordance) got real ugly real fast on accessibility audits.

**Where to use it.** Almost nowhere on a transactional product. The one place it works is non-interactive decorative dimensionality — small flourishes on stat cards, pressed-state feedback on a primary CTA button, ambient surfaces behind hero content. Treat it as garnish, not as a system.

**Where NOT to use it.** Anywhere a user needs to identify a tap target. Anywhere a screenreader user has to navigate. Anywhere with low ambient light. Buttons especially — the second a button stops looking like a button, your conversion drops measurably.

**Recipe (used sparingly — for a stat tile, NOT for buttons).**

```swift
struct NeumorphicTile<Content: View>: View {
    @ViewBuilder var content: () -> Content
    let isPressed: Bool

    var body: some View {
        content()
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGroupedBackground))
                    .shadow(color: .black.opacity(isPressed ? 0.0 : 0.10),
                            radius: 8, x: 4, y: 4)
                    .shadow(color: .white.opacity(isPressed ? 0.0 : 0.95),
                            radius: 8, x: -4, y: -4)
            }
            // Inner shadow on press for "depressed" state
            .overlay {
                if isPressed {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.black.opacity(0.05), lineWidth: 4)
                        .blur(radius: 4)
                        .mask(RoundedRectangle(cornerRadius: 16))
                }
            }
    }
}
```

**Performance / accessibility.**
- Required: minimum 4.5:1 contrast on text. The neumorphic surface is ambient — text needs to live at full primary color.
- Add a 1pt border in low-contrast mode (`@Environment(\.colorSchemeContrast)`).
- Two shadow layers per tile is fine. Stacked into a list of 20+ it gets expensive — consider flattening with `drawingGroup()`.

**Used well by.** Almost no one in production at 2025–2026 scale. Where you see it living: meditation apps (Calm uses faint neumorphic surfaces on its session cards), some financial dashboards. If your competition isn't using it, that's a signal.

---

## 4. Gradient Backplates & Tinted Surfaces

**What it is.** Instead of a flat fill, the card surface is a soft directional gradient — usually a 5–10% luminance shift from one corner to another, or a subtle radial darkening at the edges (a vignette). Same idea as a slight shading on an architectural rendering: it tells the eye there's a light source somewhere, which immediately suggests dimensionality.

**Where to use it.** On the card body itself when you want depth without shadow chaos. On hero panels, feature cards, full-bleed promo blocks. Particularly good when paired with image-extracted color tinting (technique #5) — a card whose backplate gradient is sampled from the hero image inside it.

**Where NOT to use it.** Tightly packed information cards where the visual noise drowns the data. Cards that need to feel "system" or "neutral" — gradients always carry a mood.

**Recipe.**

```swift
struct GradientBackplate: View {
    let baseTint: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        baseTint.opacity(0.08),
                        baseTint.opacity(0.02),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // SwiftUI's Color.gradient ships a free subtle gradient too:
            // .fill(baseTint.gradient.opacity(0.1))
    }
}
```

`Color.gradient` is the lazy answer — it produces a top-to-bottom shift automatically and is fine 80% of the time.

**Performance / accessibility.** Trivially cheap. No accessibility concerns as long as content contrast remains intact against the *darker* end of the gradient.

**Used well by.** Apple Fitness summary cards, Spotify's now-playing screen background, Headspace's session intros.

---

## 5. Image-Extracted Color Tinting

**What it is.** Sample the dominant color from the hero image, use it as the card's tint — backplate, accent text, button color, shadow tint. The card visually inherits from the photograph, which makes the photograph feel embedded rather than pasted on.

**Where to use it.** Anywhere the card is dominated by a single image and the rest of the card is supporting metadata. Resort cards are textbook — the pool photo dictates the mood, the rest of the card extends it. Music apps (album art → player chrome) made this canonical.

**Where NOT to use it.** Cards where multiple images coexist. Cards with brand color requirements that can't bend.

**Recipe.** Use `CIAreaAverage` for cheap "average color" or k-means clustering for "dominant" (which is what you usually want — average of a beach image is gray-tan; dominant is sky-blue).

```swift
import UIKit
import CoreImage

extension UIImage {
    /// Cheap, fast: the average color over the whole image.
    func averageColor() -> Color? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extent = inputImage.extent
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: inputImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(output,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)
        return Color(red: Double(bitmap[0]) / 255,
                     green: Double(bitmap[1]) / 255,
                     blue: Double(bitmap[2]) / 255)
    }
}

// SwiftUI consumer
struct ResortCard: View {
    let image: UIImage
    @State private var tint: Color = .gray

    var body: some View {
        VStack { /* image + content */ }
            .background(tint.opacity(0.12).gradient)
            .task {
                tint = await Task.detached(priority: .utility) {
                    image.averageColor() ?? .gray
                }.value
            }
    }
}
```

For dominant (not average) color, ColorThiefSwift or DominantColors (k-means) are battle-tested SPM packages. Don't roll your own k-means unless you enjoy debugging color spaces.

**Performance / accessibility.**
- Always extract on a background queue. `CIAreaAverage` is fast (sub-ms) but k-means on a 1000×1000 image isn't.
- Cache by image URL — recomputing on every list scroll is malpractice.
- Use the extracted color for *backplate / accent only*, never for body text. The contrast guarantee is gone the moment you derive color from arbitrary content.

**Used well by.** Apple Music (player chrome), Spotify (album page), Pinterest (board tints), Letterboxd (review cards on iOS).

---

## 6. Parallax on Scroll (Image Moves Slower Than Card)

**What it is.** As the user scrolls, the foreground content moves at scroll speed but the image inside the card moves slower. The image looks like it's behind the card frame, like a window onto a deeper plane. iOS 17 made this trivial with `.scrollTransition` and `.visualEffect`.

**Where to use it.** Hero images on detail screens (the "stretchy header" pattern). List cards with large hero photos. Anywhere the content is image-led.

**Where NOT to use it.** Dense text lists. Tab content where users are switching contexts rapidly — parallax delays the perception of "I'm now somewhere new."

**Recipe (iOS 17+, native).**

```swift
struct ParallaxImageCard: View {
    let imageName: String

    var body: some View {
        GeometryReader { proxy in
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width,
                       height: proxy.size.height + 60)
                .offset(y: parallaxOffset(for: proxy))
                .clipped()
        }
        .frame(height: 220)
    }

    private func parallaxOffset(for proxy: GeometryProxy) -> CGFloat {
        let frame = proxy.frame(in: .named("scroll"))
        // Image moves at half scroll speed
        return -frame.minY / 2
    }
}

// In the parent ScrollView:
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(resorts) { resort in
            ParallaxImageCard(imageName: resort.image)
        }
    }
}
.coordinateSpace(name: "scroll")
```

For modern iOS 17+ scroll-driven effects, prefer `.visualEffect`:

```swift
Image(imageName)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .visualEffect { content, proxy in
        let frame = proxy.frame(in: .scrollView(axis: .vertical))
        return content.offset(y: -frame.minY * 0.3)
    }
```

`.visualEffect` runs on the render thread — no SwiftUI body re-eval, no layout invalidation. Always prefer it over GeometryReader-driven parallax for production.

**Performance / accessibility.**
- Always honor `@Environment(\.accessibilityReduceMotion)`. Parallax is motion. Skip it (or weaken it to 0.05x) when the user has asked for less.
- `.visualEffect` is the cheap route. GeometryReader-driven offset triggers layout — fine for one card, painful in a list of 40.

**Used well by.** Apple News feature articles, Airbnb listing detail (header image), Spotify's "Made for You" hero cards.

---

## 7. 3D Tilt Response (CMMotionManager)

**What it is.** The card subtly rotates around X and Y axes as the user tilts the phone. Pitch shifts the top edge; roll shifts the side. The image inside the card moves slightly faster than the card itself — same parallax principle, on a different input axis.

**Where to use it.** Sparingly. One hero card on a detail screen. A tap-to-reveal "premium" interaction. Apple uses it on Apple Card visualization. *Never* on every card in a list.

**Where NOT to use it.** Anywhere it isn't the focal element. Anywhere it'd run while scrolling. Battery-sensitive contexts — `CMMotionManager` is constantly polling.

**Recipe.**

```swift
import CoreMotion
import SwiftUI

@Observable
final class MotionManager {
    var roll: Double = 0
    var pitch: Double = 0
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            self?.roll = motion.attitude.roll
            self?.pitch = motion.attitude.pitch
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

struct TiltCard: View {
    @State private var motion = MotionManager()

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.tint.gradient)
            .frame(width: 320, height: 200)
            .rotation3DEffect(
                .degrees(motion.pitch * 8),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(motion.roll * 8),
                axis: (x: 0, y: 1, z: 0)
            )
            .shadow(
                color: .black.opacity(0.25),
                radius: 20,
                x: motion.roll * 12,
                y: 8 + motion.pitch * 12
            )
            .onAppear { motion.start() }
            .onDisappear { motion.stop() }
    }
}
```

The shadow x/y offset following the tilt is the bit that sells the illusion — without it the card just rotates, with it the card looks lit by a stationary lamp.

**Performance / accessibility.**
- Hard-stop motion updates on `.onDisappear`. Don't leak an active sensor when the user navigates away.
- Honor `.accessibilityReduceMotion`. Disable the effect entirely when on.
- Clamp the tilt range — large rotations look like glitches, not effects. ±8° is the upper bound that still reads as "alive."

**Used well by.** Apple's Wallet card animations, the original Pokémon TCG Pocket app's card-flip.

---

## 8. Asymmetric Layouts (Breaking the Strict Grid)

**What it is.** Instead of every card being the same width and height, a feed mixes large cards, medium cards, and stacked smaller cards. The eye reads the difference as priority and as physical depth — bigger means closer, smaller means further away. Bento grids took this mainstream in 2024.

**Where to use it.** Editorial-feeling feeds. Discovery surfaces where you want users to *browse*, not scan. Curated sections.

**Where NOT to use it.** Comparison surfaces (search results, price ladders). Anywhere users need to scan a uniform list.

**Recipe.** Use `LazyVGrid` with mixed `GridItem` types, or hand-build with `HStack`/`VStack` for more control.

```swift
struct AsymmetricFeed: View {
    let items: [Resort]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Hero — full width, tall
                ResortCard(resort: items[0])
                    .frame(height: 280)

                // 2-up row
                HStack(spacing: 12) {
                    ResortCard(resort: items[1])
                        .frame(height: 200)
                    VStack(spacing: 12) {
                        ResortCard(resort: items[2])
                        ResortCard(resort: items[3])
                    }
                    .frame(height: 200)
                }

                // Wide editorial card
                ResortCard(resort: items[4])
                    .frame(height: 160)
            }
            .padding(.horizontal, 16)
        }
    }
}
```

For a true masonry (Pinterest-style) layout where each card auto-sizes to its content, SwiftUI doesn't ship one out of the box. The community pattern is two `LazyVStack` columns side-by-side, alternating which column receives the next item — works but doesn't balance heights perfectly. Custom `Layout` (iOS 16+) gives you the proper solution.

**Performance / accessibility.**
- Asymmetric layouts mess with VoiceOver's reading order if you're not careful. Set explicit `.accessibilitySortPriority` on each card or wrap groups in `.accessibilityElement(children: .contain)` with a clear label.
- Heights computed from content can cause layout thrash on first paint. Cache image dimensions if the image determines the card height.

**Used well by.** Pinterest (the canonical example), Apple News' "For You" feed, Airbnb's category landing pages.

---

## 9. Floating Chips & Overlapping Elements

**What it is.** A small UI atom (price pill, badge, save button) that visually straddles two surfaces — half on the image, half on the card body. The overlap reads as "this thing is sitting on top of those things," which immediately introduces a z-axis.

**Where to use it.** Price pills on resort cards (canonical). Save/heart buttons on photos. "New" badges on content. Avatar stacks on collaborative lists.

**Where NOT to use it.** When the overlap obscures content the user needs. When the chip itself is the primary action — straddling makes its tap target ambiguous.

**Recipe.**

```swift
struct ResortCard: View {
    let resort: Resort

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack(alignment: .bottomTrailing) {
                Image(resort.heroImage)
                    .resizable()
                    .aspectRatio(16/10, contentMode: .fill)
                    .clipped()

                // Floating price pill — straddles image/body boundary
                Text(resort.priceFormatted)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: .capsule)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .offset(y: 20) // push below the image edge
                    .padding(.trailing, 16)
            }

            // Body content
            VStack(alignment: .leading, spacing: 6) {
                Text(resort.name).font(.headline)
                Text(resort.location).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 28) // make room for the protruding pill
            .padding(16)
        }
        .background(Color(.systemBackground), in: .rect(cornerRadius: 16))
        .layeredShadow(elevation: 1.0)
    }
}
```

The trick is the `offset(y: 20)` paired with the `padding(.top, 28)` on the body — the pill is rendered relative to the image but visually lives on the card body. Don't clip the outer container or the pill disappears.

**Performance / accessibility.**
- The pill needs `.accessibilityElement(children: .combine)` so VoiceOver reads "$150 per day" as one item, not split into "150" / "per day".
- Tap target must remain ≥44pt. The pill should be padded out, not just visually sized.
- Watch the contrast on the pill text against *both* the image (top half) and the card surface (bottom half). Use a glass material so the chip adapts to whatever's behind it on each side.

**Used well by.** Airbnb (the price pill on listings is the textbook execution), Booking.com cards, Resy's restaurant cards.

---

## 10. Subtle Inner Highlights / "Lifted Glass" Strokes

**What it is.** A 0.5–1pt stroke at the top edge of a card or chip, very light (white at 30–60% opacity in light mode, white at 10–20% in dark mode), fading to nothing at the bottom. It mimics the catchlight on a piece of glass that's lit from above — the eye reads it as "this surface is slightly raised and reflecting the room."

**Where to use it.** Glass surfaces (it pairs with `.ultraThinMaterial` to make the glass feel like glass instead of like a tinted rectangle). Premium/feature cards. Pressed-state buttons that sit on dark surfaces.

**Where NOT to use it.** White-on-white surfaces — there's no contrast for the highlight to live in. Anywhere the design language is otherwise flat — one rogue lifted-glass card looks like a bug.

**Recipe.**

```swift
extension View {
    func liftedGlass(cornerRadius: CGFloat = 16) -> some View {
        self.overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.5),  // top edge — bright
                            .white.opacity(0.05), // mid — dim
                            .clear                // bottom — gone
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
    }
}

// Usage on a glass card
RoundedRectangle(cornerRadius: 16)
    .fill(.ultraThinMaterial)
    .liftedGlass()
```

**Performance / accessibility.** Free. Single overlay, no off-screen pass.

**Used well by.** iOS 26's Liquid Glass (which is exactly this technique productized), Apple's Control Center, Vision Pro chrome.

---

## 11. Material Thickness — Stacked Surfaces with Depth Between

**What it is.** Multiple surfaces of varying material thickness layered on top of each other, with each successive surface sitting "closer" to the user. The blur differentiation (`.thickMaterial` over `.thinMaterial` over a photograph) creates a sense of depth without a single shadow.

**Where to use it.** Floating sheets over cards. Modal-over-modal contexts (a filter sheet that itself shows a quick popover). Detail headers where a chip floats over a thicker hero card.

**Where NOT to use it.** Anywhere battery is at premium — every additional material is another GPU pass. Three stacked materials in a scrolling list is a sin.

**Recipe.**

```swift
ZStack(alignment: .top) {
    // Layer 0 — photograph (deepest)
    Image("hero")
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(height: 400)

    // Layer 1 — thin material card (middle)
    VStack { /* content */ }
        .padding(20)
        .background(.thinMaterial, in: .rect(cornerRadius: 20))
        .padding(.top, 200)
        .padding(.horizontal, 16)
        .liftedGlass(cornerRadius: 20)

    // Layer 2 — thick material chip (closest)
    HStack { Image(systemName: "sun.max.fill"); Text("Open today") }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thickMaterial, in: .capsule)
        .padding(.top, 180)
        .liftedGlass(cornerRadius: 999)
}
```

The thickness gradient (thin → thick as you climb the z-axis) is critical. If the chip and the card both use `.ultraThinMaterial`, they read as the same plane.

**Performance / accessibility.** Each material is a real-time blur — count them. Three is the practical max on iPhone. Honor `.accessibilityReduceTransparency`.

**Used well by.** iOS Lock Screen widgets, Vision Pro window chrome, Apple Music's now-playing → up next sheet.

---

## 12. Backdrop Blur Over Scrolling Content

**What it is.** A sticky surface (nav bar, tab bar, header) that stays anchored while content scrolls beneath it, with that content visibly blurred under the surface. The blur is what tells the eye that the surface has thickness — it's a window of frosted glass over moving traffic.

**Where to use it.** Sticky headers on long scrollable detail pages. Tab bars over content. A bottom action bar (like Airbnb's "Reserve" CTA) on a long-scroll listing detail.

**Where NOT to use it.** When the sticky element is the same color as the content. When the content underneath is a video — blur over video at 60fps is GPU murder.

**Recipe.** iOS 17+ gives you scroll edge effects out of the box for `ScrollView`/`List`. For a custom sticky header:

```swift
struct DetailScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image("hero").resizable().aspectRatio(contentMode: .fill).frame(height: 320)
                LongContent()
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) {
            HStack {
                Button { } label: { Image(systemName: "chevron.left") }
                Spacer()
                Button { } label: { Image(systemName: "heart") }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
            .ignoresSafeArea(edges: .top)
        }
    }
}
```

For a header that fades in only as the user scrolls past the hero:

```swift
@State private var scrollOffset: CGFloat = 0

// In your ScrollView
.onScrollGeometryChange(for: CGFloat.self) { geo in
    geo.contentOffset.y
} action: { _, newValue in
    scrollOffset = newValue
}

// Header opacity binds to scroll
.overlay(alignment: .top) {
    HeaderBar()
        .opacity(min(1, max(0, scrollOffset / 200)))
}
```

(`onScrollGeometryChange` is iOS 18+. On iOS 17, you'd use a `GeometryReader` inside the ScrollView writing to a `PreferenceKey`.)

**Performance / accessibility.**
- The blur is a per-frame cost. On a long scroll, that cost is paid every frame.
- Tap targets in the blurred region must remain accessible — don't reduce contrast on icons just because the bar is glass.

**Used well by.** Apple's stock Settings.app, Mail, almost every first-party Apple iOS detail screen.

---

## 13. Animated Gradients (Shimmer, Breathing Accents)

**What it is.** A gradient that animates — either by scrubbing across the surface (shimmer, classic loading state) or by softly cycling its colors in place (a breathing accent on a CTA, an ambient glow under a hero image). On iOS 17 the `phaseAnimator` makes both trivial.

**Where to use it.**
- **Shimmer** — skeleton loading states. Don't use a spinner where you can use a shimmer; the shimmer feels like progress, the spinner feels like waiting.
- **Breathing** — premium CTAs, "live now" indicators, focus states.

**Where NOT to use it.** Anywhere the user is reading. Animated gradients drag the eye, which is exactly why they work for loading and exactly why they sabotage comprehension elsewhere.

**Recipe (shimmer).**

```swift
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.5), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
                .mask(content)
                .offset(x: phase * 300)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View { func shimmer() -> some View { modifier(Shimmer()) } }

// Usage on a skeleton row
RoundedRectangle(cornerRadius: 8)
    .fill(.gray.opacity(0.2))
    .frame(height: 16)
    .shimmer()
```

**Recipe (breathing — iOS 17 phaseAnimator).**

```swift
Circle()
    .fill(.red)
    .frame(width: 12, height: 12)
    .phaseAnimator([1.0, 0.4]) { content, phase in
        content
            .opacity(phase)
            .scaleEffect(phase == 1.0 ? 1.0 : 0.85)
    } animation: { _ in
        .easeInOut(duration: 1.0)
    }
```

**Performance / accessibility.**
- Stop animations when off-screen. SwiftUI handles this for views in lazy stacks but verify on your scroll surfaces.
- Honor `.accessibilityReduceMotion` — replace shimmer with a static muted color, replace breathing with a steady state.

**Used well by.** Linear's loading states (web, but the pattern is identical), Instagram's skeleton feeds, Things 3's quick-add focus indicator.

---

## 14. Drop Caps & Typographic Dimensionality

**What it is.** The first letter of a paragraph at 3–4× body size, sometimes hung into the margin, sometimes wrapped by the body text. Hung quotes — actual quote marks that visually break out of the text column. Both are typography pretending to be architecture: the eye reads the size differential as physical projection.

**Where to use it.** Editorial sections. Long-form descriptions. The "About this resort" intro. Anywhere you want a moment to feel literary and considered, not transactional.

**Where NOT to use it.** Card titles — drop caps in lists are visual noise. Functional UI text. Localized text that may not start with a Latin character.

**Recipe.** SwiftUI doesn't ship a true wraparound drop cap. You can fake the most common version (the letter sitting on its own line, baseline-aligned with the next two lines of body) using `Text` concatenation:

```swift
struct DropCap: View {
    let cap: String
    let body: String

    var body: some View {
        (Text(cap)
            .font(.custom("NewYork-Regular", size: 56).weight(.semibold))
            .foregroundStyle(.primary)
         + Text(body)
            .font(.system(size: 17))
            .foregroundStyle(.secondary))
            .lineSpacing(6)
            .multilineTextAlignment(.leading)
    }
}

// Usage
DropCap(
    cap: "T",
    body: "he Aman Tokyo sits 33 floors above the Otemachi district…"
)
```

For true wraparound (the body reflows around the cap), TextKit 2 inside a `UIViewRepresentable` is the only path. Worth it for one editorial screen, not for a system component.

For hung quotes — wrap a `Text` in a hanging-indent layout:

```swift
HStack(alignment: .top, spacing: 8) {
    Text("\u{201C}")
        .font(.largeTitle)
        .foregroundStyle(.tertiary)
        .offset(y: -4)
    Text(quoteText)
        .font(.body)
}
```

**Performance / accessibility.**
- VoiceOver reads the cap and the body as two separate runs unless you concatenate. Always concatenate.
- Dynamic Type: the cap should scale with `.dynamicTypeSize` but with a smaller ratio than body — at AX5, a 4× cap becomes a 200pt monstrosity. Clamp.

**Used well by.** Apple's Editor's Notes in App Store, Letterboxd reviews, NYT Cooking recipe intros.

---

## 15. Soft Shadows Under Text on Photos

**What it is.** Text laid directly over a photographic background, with a soft drop shadow underneath — not for decoration, but for legibility. The shadow doesn't read as a shadow consciously; it reads as the text being slightly "in front of" the image. Same trick a movie poster designer has used for 80 years.

**Where to use it.** Hero text over a photo. Card titles that overlay the image rather than sitting in a card body. Onboarding screens with full-bleed imagery.

**Where NOT to use it.** As a substitute for a scrim. If the image is busy enough that you need a strong shadow, you needed a gradient overlay instead — the shadow alone won't save you.

**Recipe.**

```swift
struct PhotoHeroCard: View {
    let image: String
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fill)

            // Scrim — bottom-anchored gradient for legibility floor
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 1)
            }
            .padding(20)
        }
        .frame(height: 280)
        .clipShape(.rect(cornerRadius: 20))
    }
}
```

The combination is doing the work — the gradient scrim guarantees a legibility floor, the soft shadow gives the text an edge against any image. Either alone is fragile.

**Performance / accessibility.**
- Always test against a worst-case image (a photo of pure white sand, a photo of pure white sky). If the gradient scrim isn't enough, deepen it before deepening the shadow.
- WCAG contrast must hold against the *darkest band of the gradient at the text's vertical position.* Don't trust eyeballing.

**Used well by.** Apple's App Store featured cards, Airbnb's category headers, Spotify's playlist art.

---

## How These Compose for the Resort Card

The brief was "the cards feel flat." Almost certainly the fix isn't one of these techniques. It's the right four, layered:

1. **Layered shadow** (#1) under the card — the contact + cast + falloff stack.
2. **Floating price pill** (#9) straddling the image/body boundary, built as a glass chip (#2) with a lifted-glass stroke (#10).
3. **Image-extracted tint** (#5) feeding a subtle gradient backplate (#4) on the card body.
4. **Soft text shadow + scrim** (#15) on the hero image overlay, only if the title sits on the photo.

Optional, depending on context:
- **Parallax on scroll** (#6) for the detail screen, not the list.
- **Asymmetric layout** (#8) at the feed level — one hero card per screen, not every card the same size.

Skip:
- Neumorphism (#3) — accessibility liability for a transactional product.
- 3D tilt (#7) — too gimmicky for a list of cards. Reserve for a single moment of premium delight if there is one.
- Shimmer/breathing (#13) — only as loading states, not as decoration.

The principle underneath all of them is the same: **depth is reinforcement, not loudness.** Each technique alone is invisible. The card feels deep when four invisible things agree.

---

## Sources

- [ShadowKit — SwiftUI layered shadow package](https://github.com/metasidd/ShadowKit-SwiftUI)
- [Hacking with Swift — Inner shadows + Core Motion](https://www.hackingwithswift.com/articles/253/how-to-use-inner-shadows-to-simulate-depth-with-swiftui-and-core-motion)
- [Hacking with Swift+ — Shadows and glows](https://www.hackingwithswift.com/plus/swiftui-special-effects/shadows-and-glows)
- [Sami Gündoğan — Liquid Glass in SwiftUI & UIKit](https://medium.com/icommunity/liquid-glass-in-swiftui-uikit-77d480db1d29)
- [NN/g — Glassmorphism: Definition and Best Practices](https://www.nngroup.com/articles/glassmorphism/)
- [SwiftFoxx — All About Glass Effect](https://www.swiftfoxx.org/all-about-glass-effect/)
- [Apple — Create custom visual effects with SwiftUI (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10151/)
- [Apple — Beyond scroll views (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10159/)
- [SwiftUI Handbook — Parallax ScrollView](https://designcode.io/swiftui-handbook-parallax-scrollview/)
- [Trailing Closure — SwiftUI Parallax Motion Effect](https://trailingclosure.com/device-motion-effect/)
- [Rudrank Riyam — Extract prominent colors from UIImage](https://rudrank.com/exploring-core-graphics-extract-prominent-unique-colors-uiimage)
- [DominantColors — k-means image color extraction](https://github.com/DenDmitriev/DominantColors)
- [UIImageColors — battle-tested dominant color package](https://github.com/jathu/UIImageColors)
- [Big Human — Neumorphism: A Complete 2026 Guide](https://www.bighuman.com/blog/neumorphism)
- [Webflow Blog — Neumorphism rise and fall](https://webflow.com/blog/neumorphism)
- [Sarunw — Bevel effect using inner shadows](https://sarunw.com/posts/how-to-make-bevel-effect-in-swiftui/)
- [SwiftUI Handbook — Mesh Gradient](https://designcode.io/swiftui-handbook-mesh-gradient/)
- [Donny Wals — Mesh Gradients on iOS 18](https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/)
- [SwiftUI-Shimmer — markiv](https://github.com/markiv/SwiftUI-Shimmer)
- [Design+Code — Phase Animator](https://designcode.io/swiftui-ios17-phase-animator/)
- [Holy Swift — Card with image outside its bounds](https://holyswift.app/create-a-card-with-an-image-outside-its-bounds-in-swiftui/)
- [SwiftUISnippets — Scrim gradient overlay](https://swiftuisnippets.wordpress.com/2024/07/18/adding-a-scrim-gradient-overlay-to-images-with-swift/)
- [Bloomberg — Apple, Airbnb ditch flat icons for 3D UI](https://www.bloomberg.com/news/articles/2025-06-13/apple-airbnb-ditch-flat-app-icons-for-new-3d-ui-design)
- [Design Compass — Airbnb's new design system](https://designcompass.org/en/2025/07/04/airbnb-new-design-system/)
- [It's Nice That — Airbnb app redesign](https://www.itsnicethat.com/articles/airbnb-app-redesign-140525)
- [Hacking with Swift — Scroll edge effect](https://www.hackingwithswift.com/quick-start/swiftui/how-to-adjust-the-scroll-edge-effect-for-scrollview-and-list)
- [Hacking with Swift — visualEffect and scrollTargetBehavior](https://www.hackingwithswift.com/books/ios-swiftui/scrollview-effects-using-visualeffect-and-scrolltargetbehavior)
- [Apple — Layering content concepts tutorial](https://developer.apple.com/tutorials/swiftui-concepts/layering-content)
- [Google Fonts — Drop cap glossary](https://fonts.google.com/knowledge/glossary/drop_cap)
