# Image Gallery & Gradient Overlay Patterns for Hotel Cards (SwiftUI iOS 17+)

Hospitality apps live and die by their hero imagery. A hotel card without a great photo is a price tag without context. This document walks through every pattern we'll consider for the gallery surface inside the hotel card, plus the gradient/text/legibility tooling that makes those photos work as a substrate for content. All recipes assume Kingfisher 7+ and SwiftUI on iOS 17+.

---

## 1. TabView with `.page` style — the default we should reach for first

`TabView` with `PageTabViewStyle` is the path of least resistance. Apple gives us native paging, accessibility, and gesture handling for free. For most hotel cards in a list, this is the right answer.

```swift
TabView {
    ForEach(hotel.imageURLs.indices, id: \.self) { i in
        KFImage(hotel.imageURLs[i])
            .placeholder { ImagePlaceholder() }
            .fade(duration: 0.2)
            .cancelOnDisappear(true)
            .resizable()
            .scaledToFill()
            .clipped()
    }
}
.tabViewStyle(.page(indexDisplayMode: .always))
.indexViewStyle(.page(backgroundDisplayMode: .always))
.frame(height: 220)
.clipShape(RoundedRectangle(cornerRadius: 12))
```

**Page indicator customization.** The native dots inherit from `UIPageControl`'s appearance. Apply via UIKit appearance proxy in `init`:

```swift
init() {
    UIPageControl.appearance().currentPageIndicatorTintColor = .white
    UIPageControl.appearance().pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.4)
}
```

Tinting is global — scope it with appearance containers if you have other page controls in the app:

```swift
UIPageControl.appearance(whenContainedInInstancesOf: [UIHostingController<HotelCard>.self])
    .currentPageIndicatorTintColor = .white
```

**iOS 17 changes.** `indexDisplayMode: .always` now respects safe areas more aggressively. If the dots collide with content underneath, wrap the `TabView` in a fixed-frame container and use `.contentMargins` on the outer scroll view rather than fighting the indicator position.

**Pros:** native gesture engine, free VoiceOver paging, automatic RTL flip, zero state to manage.
**Cons:** indicator position is fixed at bottom-center, no built-in counter ("1/5"), customization beyond tint requires UIKit appearance hacks. All children are eagerly evaluated — this matters for image preloading (see §4).

**Use when:** the gallery sits inside a list cell, has 2–10 images, and you don't need a custom indicator.

---

## 2. Custom HStack + offset carousel — when you need control

Roll your own only when TabView's constraints actually bite: custom indicator placement, peek-at-next-image effect, non-paging momentum, or arbitrary item widths.

```swift
struct CustomCarousel<Content: View>: View {
    let count: Int
    let content: (Int) -> Content
    @State private var offset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @Binding var index: Int

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    content(i).frame(width: geo.size.width)
                }
            }
            .offset(x: -CGFloat(index) * geo.size.width + dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation.width }
                    .onEnded { value in
                        let threshold = geo.size.width * 0.25
                        let predicted = value.predictedEndTranslation.width
                        var newIndex = index
                        if predicted < -threshold, index < count - 1 { newIndex += 1 }
                        if predicted >  threshold, index > 0          { newIndex -= 1 }
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                            index = newIndex
                            dragOffset = 0
                        }
                    }
            )
        }
    }
}
```

The key bits: use `predictedEndTranslation` (not raw translation) so flicks register, set a threshold around 20–30% of width to bias toward staying on the current page, and animate with a spring that doesn't overshoot.

**Use when:** you need a card-stack effect where the next image peeks 20pt off the trailing edge, or when image widths vary, or when you want to suppress paging entirely (continuous scroll with momentum).

**Don't use when:** TabView would do. Hand-rolled gesture state is a tax — you'll re-derive accessibility behavior, RTL, and edge-bounce yourself.

---

## 3. iOS 17 `ScrollView` + `scrollTargetBehavior(.paging)` — the modern compromise

This is the sweet spot for new code on iOS 17+. You get native paging with a real `ScrollView` underneath, which means proper lazy loading, scroll position binding, and customizable indicators.

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 0) {
        ForEach(Array(hotel.imageURLs.enumerated()), id: \.offset) { i, url in
            KFImage(url)
                .placeholder { ImagePlaceholder() }
                .fade(duration: 0.2)
                .cancelOnDisappear(true)
                .resizable()
                .scaledToFill()
                .containerRelativeFrame(.horizontal)
                .clipped()
                .id(i)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)
.scrollIndicators(.hidden)
.scrollPosition(id: $currentIndex)
.frame(height: 220)
```

`containerRelativeFrame(.horizontal)` is the trick — it sizes children to the scroll view's width without `GeometryReader`. `scrollTargetLayout()` marks the layout that contributes targets to the paging behavior. `scrollPosition(id:)` gives us a binding to the current page for our custom indicator (see §5).

**When this is the right choice:** new iOS 17+ projects, when you need a custom indicator bound to scroll position, when you want lazy child evaluation (TabView eagerly evaluates all pages), or when you want analytics on scroll progress without gesture introspection.

**Caveat:** `cancelOnDisappear(true)` plus `LazyHStack` means images two-pages-away won't even start loading. That's usually what we want, but see §4 for prefetching.

---

## 4. Image preloading — load the first, prefetch the next

The naive approach loads all gallery images on cell appear. On a list of 50 hotels with 5 images each, that's 250 image requests racing for bandwidth. The user will see image #1 of hotel #1 before they see image #1 of hotel #50. This is the wrong order.

**Tier 1 — only image[0] is eager.** Every other image lazy-loads on swipe. This is the default for `LazyHStack` + `cancelOnDisappear(true)`. Start here.

**Tier 2 — prefetch image[1] on cell appear.** Most users who swipe at all swipe once. Prefetching just the second image hides the network latency of that first swipe.

```swift
struct HotelGallery: View {
    let urls: [URL]
    @State private var currentIndex = 0

    var body: some View {
        carousel
            .onAppear { prefetch(urls.prefix(2)) }
            .onChange(of: currentIndex) { _, newIndex in
                let window = max(0, newIndex - 1)...min(urls.count - 1, newIndex + 1)
                prefetch(urls[window])
            }
    }

    private func prefetch(_ urls: any Collection<URL>) {
        ImagePrefetcher(urls: Array(urls)).start()
    }
    // ...
}
```

`ImagePrefetcher` writes into Kingfisher's cache without rendering. Subsequent `KFImage` requests for those URLs hit the cache and render instantly. Cancel by calling `.stop()` on the prefetcher if the user scrolls away — keep the reference if you go this route.

**Tier 3 — prefetch hotel[i+1].images[0] when hotel[i] is on screen.** For the parent list. Combine with `onAppear` on the cell. This is the most expensive tier — gate behind `Reachability.isExpensive == false` to respect cellular.

---

## 5. Pagination indicator — dots, bars, or counter

Three legible options, in order of information density:

**Dots.** Default for ≤5 images. Stops working past 7 — visual noise overwhelms. Use the native `IndexViewStyle` if you accept the bottom-center position; build your own if you don't.

```swift
HStack(spacing: 6) {
    ForEach(0..<count, id: \.self) { i in
        Circle()
            .fill(i == currentIndex ? Color.white : Color.white.opacity(0.4))
            .frame(width: 6, height: 6)
            .animation(.easeInOut(duration: 0.2), value: currentIndex)
    }
}
.padding(.horizontal, 10).padding(.vertical, 6)
.background(.black.opacity(0.3), in: Capsule())
```

**Progress bar.** Best for 6+ images, video stories, or anywhere image count is variable. Less prone to dot-soup.

**Counter ("3/12").** Best for galleries with 10+ images, when count is meaningful (room photos, all hotel images on detail screen). Pair with a dot or bar for proximate-state feedback.

```swift
Text("\(currentIndex + 1) / \(count)")
    .font(.caption.weight(.medium))
    .foregroundStyle(.white)
    .padding(.horizontal, 10).padding(.vertical, 4)
    .background(.black.opacity(0.4), in: Capsule())
```

**Position.** Bottom-center for hero cards, bottom-right when text content sits bottom-left (price + name). Always overlay on the image with a subtle dark capsule background — never let dots float on raw photo pixels (the third image will always have a white sky and your white dots will vanish).

**Visibility.** Always visible for static cards. Auto-hide after 2s of no interaction for full-screen lightbox views. Never auto-hide in a list — the user needs the affordance to know the image is swipable.

---

## 6. Gradient overlay for legibility

The single highest-leverage technique in this entire document. A `LinearGradient` from black (60% opacity) at the bottom to clear at ~40% up the image makes any white text legible on any photo.

```swift
ZStack(alignment: .bottomLeading) {
    KFImage(hotel.heroURL).resizable().scaledToFill()

    LinearGradient(
        stops: [
            .init(color: .black.opacity(0.6), location: 0.0),
            .init(color: .black.opacity(0.3), location: 0.4),
            .init(color: .clear,              location: 1.0)
        ],
        startPoint: .bottom,
        endPoint: .top
    )

    VStack(alignment: .leading, spacing: 4) {
        Text(hotel.name).font(.headline).foregroundStyle(.white)
        Text(hotel.location).font(.subheadline).foregroundStyle(.white.opacity(0.85))
    }
    .padding(16)
}
.clipped()
```

**The stops matter.** A two-stop gradient (`.black.opacity(0.6)` to `.clear`) creates a hard knee in the middle of the image. The three-stop version above with an intermediate 30% point at 40% height produces a softer falloff that's perceptually invisible while still doing the contrast work. Always use a stops-array, never the two-color shorthand, for hero gradients.

**For top-of-image content** (status badges, save button), mirror the gradient at the top with lower opacity (`0.3` → `clear` over the top 30%). Most cards don't need this — only when you're putting text or icons up there.

**For full-image overlay** (when text sits centered), a flat `.black.opacity(0.35)` is more honest than a gradient. Don't fake a gradient when you actually want a scrim.

---

## 7. Text-on-image legibility

Gradient is necessary but not sufficient. Three more rules:

1. **Minimum weight is `.medium`.** Regular weight white text on a busy gradient reads as static. Medium is the floor. Headline weight (`.semibold`) for the hotel name, medium for everything else.
2. **Subtle shadow, not heavy.** `.shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)`. Anything heavier reads as a 2008-era PowerPoint deck. The shadow is insurance for the 3% of edge cases where the gradient isn't enough — it shouldn't be visible as a design element.
3. **Never pure white.** `.white` is `#FFFFFF`. On a photo, that's harsh. Use `.white.opacity(0.95)` for headings, `.white.opacity(0.85)` for body. The eye reads it as white but the fringing is softer.

```swift
Text(hotel.name)
    .font(.system(size: 17, weight: .semibold))
    .foregroundStyle(.white.opacity(0.95))
    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
```

For accessibility, audit with a 4.5:1 contrast ratio against the *darkest* point of the gradient over the *brightest* image you'll realistically serve. If a sun-bleached pool photo passes, everything passes.

---

## 8. Image fade-in patterns

Three failure modes to avoid: pop-in (image appears with no transition), white-flash (placeholder is white, image is dark, jarring), and lingering placeholder (image loaded but the placeholder is still painted on top because of timing).

**Default — `.fade(duration: 0.2)`.** Kingfisher cross-fades from placeholder to image. 200ms is the sweet spot — fast enough not to feel slow, slow enough to register as intentional.

```swift
KFImage(url)
    .placeholder { ImagePlaceholder() }
    .fade(duration: 0.2)
    .resizable()
    .scaledToFill()
```

**Skeleton placeholder (preferred).** A neutral gray rectangle with optional shimmer. Matches the size of the loaded image, so there's no layout shift.

```swift
struct ImagePlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay(ShimmerOverlay())
    }
}
```

**Blur-up (when you have a thumbnail).** Server-provided low-res placeholder, blurred, swapped for full-res on load. Twice as much work for marginal benefit — only use on hero detail screens, not list cells.

```swift
KFImage(url)
    .placeholder {
        KFImage(thumbnailURL).resizable().scaledToFill().blur(radius: 20)
    }
    .fade(duration: 0.3)
```

**When to skip the fade.** Cache hits. Kingfisher's `.fade` runs even on cache reads, which feels wrong — the image was instant, why is it fading? Use `.onlyFromCache(false)` plus a check or use `.fade(duration: cacheHit ? 0 : 0.2)` with a custom modifier. For our use case, 200ms on cache hits is acceptable; revisit if it starts feeling sluggish.

---

## 9. Aspect ratio handling — variable images from the API

Hotel APIs return images at whatever aspect ratio the property uploaded. Three approaches, in order of preference:

**Fixed-frame + `scaledToFill` + `clipped`.** The right default. Forces every image into the same card slot (16:9 or 3:2), crops the overflow. Most hotel images are landscape so cropping is minimal.

```swift
KFImage(url)
    .resizable()
    .scaledToFill()
    .frame(height: 220)
    .frame(maxWidth: .infinity)
    .clipped()
```

**Aspect-fit with letterboxing.** Use when image content is critical (floor plans, amenity diagrams). Pads with a background color. Almost never right for hero photos.

**Variable-height cards.** API returns aspect ratio, card sizes to match. Looks great for Pinterest-style grids, kills list scrolling performance because cells aren't uniform-height. Only use in waterfall layouts.

For our hotel cards: fixed 220pt height with `scaledToFill` and `clipped`. The crop bias should be center for hero shots, top for property exteriors (sky in upper third is fine to lose, signage is not).

---

## 10. Branded image fallback

When `imageURL` is nil or the request fails, "broken image icon" is a cardinal sin. Three options, in order of polish:

**Logo + brand gradient + name overlay.** Looks like an intentional designed card, not a failure state.

```swift
struct BrandedFallback: View {
    let hotelName: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color("BrandPrimary"), Color("BrandSecondary")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image("LogoMark")
                .resizable().scaledToFit().frame(width: 48, height: 48)
                .opacity(0.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(hotelName)
                .font(.headline).foregroundStyle(.white)
                .padding(16)
        }
    }
}
```

**Initials avatar.** Two-letter initials over a deterministic color derived from the hotel ID hash. Cheap, recognizable, never repeats within a list.

**Generic gray box.** Acceptable only for skeleton/loading state. Never for terminal failure.

Wire it via Kingfisher:

```swift
KFImage(hotel.heroURL)
    .placeholder { ImagePlaceholder() }
    .onFailure { _ in /* log */ }
    .resizable()
    .scaledToFill()
    .background(BrandedFallback(hotelName: hotel.name)) // shown when KFImage renders nothing
```

Cleaner: branch in the view based on URL nullability, and use `.onFailureImage()` on Kingfisher for the network-failure branch.

---

## 11. Lazy loading inside `LazyVStack`

`LazyVStack` only realizes cells as they enter the scroll viewport, but Kingfisher needs hooking up correctly:

```swift
LazyVStack(spacing: 16) {
    ForEach(hotels) { hotel in
        HotelCard(hotel: hotel)
            .onAppear  { /* analytics, prefetch next */ }
            .onDisappear { /* nothing — KF handles via cancelOnDisappear */ }
    }
}
```

Inside `HotelCard`:

```swift
KFImage(url)
    .cancelOnDisappear(true)  // critical
    .placeholder { ImagePlaceholder() }
    .fade(duration: 0.2)
    .resizable()
    .scaledToFill()
```

`cancelOnDisappear(true)` is non-negotiable for lazy lists. Without it, scrolling fast through 100 cells queues 100 image requests, none of which the user will see, all of which compete for bandwidth with the cells the user *will* see. With it, only on-screen requests are alive.

**Gotcha — placeholder flicker on re-appear.** When a cell scrolls off and back, the cancelled request restarts. If the image isn't yet cached, the placeholder shows again. Solutions: (a) accept it, (b) increase `LazyVStack`'s recycling buffer with `.contentMargins(.vertical, 200)`, (c) use Kingfisher's memory cache aggressively (`cacheMemoryOnly(false)` plus disk cache means re-appears are near-instant).

---

## 12. Image performance — downsample, evict, breathe

Three knobs:

**Downsampling.** Loading a 4000×3000 JPEG to display at 360×220 is a 16x memory waste. Tell Kingfisher the target size:

```swift
KFImage(url)
    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 360, height: 220)))
    .scaleFactor(UIScreen.main.scale)
    .cacheOriginalImage()  // optional — keeps full-res on disk for lightbox
    .resizable()
    .scaledToFill()
```

`cacheOriginalImage()` stores the original on disk (so the lightbox can render full-res) but returns the downsampled version to the view. Memory cache holds the downsampled.

**Cache eviction.** Kingfisher's default cache limits are generous (memory: ~25% of total RAM, disk: 1GB). For our hotel list, tighter memory caps prevent jank under pressure:

```swift
ImageCache.default.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024  // 50MB
ImageCache.default.memoryStorage.config.expiration = .seconds(300)
ImageCache.default.diskStorage.config.sizeLimit = 200 * 1024 * 1024        // 200MB
```

Set these once at app launch.

**Memory pressure.** Kingfisher already listens for `UIApplication.didReceiveMemoryWarningNotification` and clears its memory cache. Don't override unless you've measured and have a reason. If you're seeing jank on older devices, profile with Instruments' Allocations + Time Profiler before tweaking cache sizes.

---

## 13. Kingfisher recipes — the sharp tools

The complete `KFImage` modifier chain we'll standardize on:

```swift
KFImage(url)
    .placeholder { ImagePlaceholder() }
    .onFailureImage(UIImage(named: "BrandedFallback"))
    .setProcessor(DownsamplingImageProcessor(size: targetSize))
    .scaleFactor(UIScreen.main.scale)
    .cacheOriginalImage()
    .fade(duration: 0.2)
    .cancelOnDisappear(true)
    .retry(maxCount: 2, interval: .seconds(1))
    .resizable()
    .scaledToFill()
```

**`.retry(maxCount:interval:)`** — two retries on transient failures. Don't go higher; users feel three failures as broken. Combine with `.onFailure { error in /* log to Sentry */ }` for observability.

**`.requestModifier`** — for auth headers if hotel images live behind a CDN with signed URLs.

```swift
let modifier = AnyModifier { request in
    var r = request
    r.setValue(authToken, forHTTPHeaderField: "Authorization")
    return r
}
KFImage(url).setModifier(modifier)
```

**`.lowDataModeSource(_:)`** — iOS 13+ Low Data Mode. Falls back to a smaller URL when the user has Low Data on. Hotel APIs that expose `thumbnail`/`medium`/`full` URLs can wire this directly.

```swift
KFImage.url(fullURL).lowDataModeSource(.network(thumbnailURL))
```

**`.diskCacheAccessExtendingExpiration(.cacheTime)`** — every cache hit resets the disk TTL. Long-tail hotel images stay cached as long as users keep visiting them.

---

## 14. Photo viewer / lightbox — tap-to-expand

The detail-screen interaction. Tap an image, it expands to full-screen with zoom + pan, swipe-to-dismiss.

For iOS 17+, `ScrollView` with `scrollPosition(id:)`, `.scrollTargetBehavior(.paging)`, and a `MagnificationGesture` on each child gets us 80% of the way:

```swift
struct Lightbox: View {
    let urls: [URL]
    @State private var currentIndex: Int
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(urls.indices, id: \.self) { i in
                        ZoomableImage(url: urls[i])
                            .containerRelativeFrame(.horizontal)
                            .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: .init(get: { currentIndex }, set: { currentIndex = $0 ?? 0 }))

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(.white).padding()
                    }
                }
                Spacer()
                Text("\(currentIndex + 1) / \(urls.count)")
                    .font(.caption).foregroundStyle(.white).padding()
            }
        }
        .statusBarHidden()
    }
}
```

`ZoomableImage` wraps `KFImage` in a `ScrollView` with `.zoomScales` (iOS 17+) or wraps a `UIScrollView` via `UIViewRepresentable` for finer control.

**Hero animation.** Use `matchedGeometryEffect` to animate the tapped thumbnail into the lightbox. The grid image and the lightbox image share an `id`, SwiftUI handles the rest.

```swift
@Namespace private var imageNamespace

KFImage(url)
    .matchedGeometryEffect(id: url, in: imageNamespace)
    .onTapGesture { showLightbox = true }
    .fullScreenCover(isPresented: $showLightbox) {
        Lightbox(urls: urls, namespace: imageNamespace)
    }
```

**Swipe-to-dismiss.** Track vertical drag, scale + fade the image as drag distance grows, dismiss past a threshold. Resist below the threshold with a spring back to center. Don't try to combine this with the horizontal paging gesture — let SwiftUI's gesture system arbitrate via `simultaneousGesture` or use a custom transaction.

**Loading full-res in the lightbox.** This is where `cacheOriginalImage()` from §13 pays off. The list cell rendered downsampled; the lightbox requests the same URL without a downsampling processor and gets the original from disk cache. Zero additional network.

---

## Defaults we'll use, in one place

- **Card gallery:** `TabView(.page)` for ≤5 images, `ScrollView` + `scrollTargetBehavior(.paging)` for variable counts or custom indicators.
- **Indicator:** Custom dot capsule, bottom-center, always visible, tinted white over `.black.opacity(0.3)` capsule.
- **Gradient:** Three-stop linear, `.black.opacity(0.6)` → `0.3` at 40% → `.clear`, bottom to top.
- **Text:** `.semibold` headline, `.medium` body, `.white.opacity(0.95)`, subtle 2pt shadow.
- **Aspect:** Fixed 220pt height, `scaledToFill + clipped`, center crop.
- **Kingfisher chain:** placeholder + downsample + cacheOriginal + fade(0.2) + cancelOnDisappear + retry(2).
- **Fallback:** Branded gradient + logo mark + name, never a broken-image glyph.
- **Cache caps:** 50MB memory, 200MB disk, 5min memory expiration.
- **Lightbox:** `fullScreenCover` + `matchedGeometryEffect` + paging `ScrollView` + zoom-per-image.

These defaults will get us to a polished v1. The custom HStack carousel and blur-up placeholders are escape hatches for when defaults don't hold — measure first, then deviate.
