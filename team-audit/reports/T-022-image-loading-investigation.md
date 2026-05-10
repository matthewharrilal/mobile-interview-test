# T-022 — Image Loading Investigation (covers F-024)

**Branch:** `fix/T-022-image-loading` from `audit/baseline @ d20159c`
**Scope:** Static analysis only. No code changes. Optional flow 81 added.
**Live observation:** `team-audit/screenshots/existing/01-happy-path/01-hotels-loaded.png` shows `BrandedImagePlaceholder` fallbacks (gradient + `building.2.crop.circle` symbol) on the top-of-fold `CompactHotelCard`s instead of real hotel photography.

---

## 1. Code-path summary — what placeholder rendering implies

Image rendering on the listings screen flows through two paths:

**Parallax header** (`Sources/Features/HotelListings/HotelListingsView.swift:200-211`)
- Uses `CachedAsyncImage(url: hotel.imageURL)` for the first hotel.
- `CachedAsyncImage` (`Sources/ImageCaching/CachedAsyncImage.swift`) wraps `KFImage` with `EditorialGradeProcessor` and a *plain gray* placeholder: `Color.gray.opacity(0.15)`.
- In the screenshot the header reads as a flat warm-gray gradient — consistent with this gray placeholder, NOT the branded fallback. So `imageURL` is non-nil; KFImage simply hasn't resolved.

**Card carousel** (`Sources/DesignSystem/Components/CompactHotelCard.swift:23` → `Sources/DesignSystem/Components/HotelImageCarousel.swift:36-57`)
- `CompactHotelCard` delegates image rendering to `HotelImageCarousel`.
- `HotelImageCarousel.imageContent` branches on `urls.isEmpty`:
  - `urls.isEmpty == true` → `BrandedImagePlaceholder()` is rendered directly (terminal state).
  - `urls.isEmpty == false` → `KFImage` is built per URL with `.placeholder { BrandedImagePlaceholder() }`. The branded placeholder is shown ONLY while the image is in-flight.
- Crucially, the screenshot shows the carousel paging indicator **"1 / 5"** on top of the placeholder. That counter only renders when `urls.count > 1` (`HotelImageCarousel.swift:21`). So `urls` is populated with 5 entries — we are in the second branch, sitting on the in-flight placeholder.

**Implication:** This is not a "URLs are nil" bug. The Hotel decoder (`Sources/Models/Hotel.swift:80-92`) successfully built `imageURLs` from the API's `image[]` array. The placeholder is the transient state of `KFImage` — i.e., the Kingfisher download or `EditorialGradeProcessor` pipeline has not yet completed at the moment Maestro fired `takeScreenshot`.

### Supporting evidence

`team-audit/screenshots/new/37-dark-hotels-loaded/37-dark-hotels-loaded.png` exercises the *same flow* (search → tap Newport Beach → screenshot of listings) on the same simulator with different timing. In that capture:
- Parallax header shows a real Newport Beach photo (loaded).
- "Hilton Orange…" card (second top-of-fold) shows real photography (loaded).
- "Hyatt Regency…" card (first top-of-fold) still shows `BrandedImagePlaceholder` (in-flight).

So even the dark variant captures a partially-resolved gallery. The fact that *which* cards are placeholder-state varies between captures of the same flow is the signature of a load-timing race, not a deterministic bug.

### Why timing is tight

- `EditorialGradeProcessor` (`Sources/ImageCaching/EditorialGradeProcessor.swift:30-50`) runs `CIColorControls` per image on the GPU context. Cheap per image, but it serializes on the Kingfisher decode queue and adds non-zero latency over a raw decode.
- Image hosts include `images.unsplash.com` and the `staging-app.resortpass.com` CDN (per `Sources/Networking/HotelsClient.swift` and `Sources/Networking/APIEnvironment.swift`). Cold cache on a fresh `clearState: true` launch means every URL is a network round-trip.
- No `ImagePrefetcher` is configured anywhere in the codebase (`grep -r prefetch Sources` returns nothing relevant). KFImage download starts only when the cell appears in view.
- Maestro's `waitForAnimationToEnd` waits for SwiftUI/UIKit animations to settle — not for `URLSession`/Kingfisher. Once the listings list animates in, `waitForAnimationToEnd` returns even if KFImage is still mid-download.

### Flow 01 vs flow 37 timing diff

- Flow 01 (`.maestro/01-happy-path.yaml`): waits on the *nav title* `"Newport Beach, California"` (visible the moment the navigation push lands, before data binds) → 8s `waitForAnimationToEnd` → screenshot. The 8s is fully spent on animations; not on image I/O.
- Flow 37 (`.maestro/37-dark-hotels-loaded.yaml`): waits on `"Top picks"` (a post-data-bind label) → 4s `waitForAnimationToEnd` → screenshot. Stronger gate, more even timing → more images resolved by the time the shutter fires (still not all of them).

This pinpoints the placeholder cards as a harness-timing artifact, not a runtime bug.

---

## 2. Hypotheses, ranked

| # | Hypothesis | Likelihood | Evidence |
|---|---|---|---|
| **A** | **Kingfisher cache miss + KFImage in-flight when Maestro screenshots; `waitForAnimationToEnd` does not gate on network/decode.** | **Very high (leading)** | "1 / 5" indicator visible (URLs present), header on `Color.gray.opacity(0.15)` (not branded), flow 37 captures partial resolution of the same data on the same simulator, no `ImagePrefetcher` exists, flow 01's wait is on a nav-title that lands before data. |
| C | Kingfisher prefetch tier too small / not engaged early. | Medium-low (related to A) | True that no prefetch exists, but this is a *missing optimization* not a *broken state* — it manifests as the same in-flight placeholder. Treat as a sub-cause of A. |
| B | Network failure to image hosts during test. | Low | A network failure would yield the in-flight placeholder permanently *and* would produce the same outcome on flow 37 (it doesn't — flow 37 partially resolves). Also, the parallax header is on the `Color.gray` placeholder of `CachedAsyncImage`, which Kingfisher only swaps off success — a true failure stays gray, but other captures of the same hosts succeed across the run. Not consistent with a host-down scenario. |
| D | `CachedAsyncImage` / `HotelImageCarousel` placeholder wrongly persists past load. | Very low | `KFImage(...).placeholder { ... }` is a stock Kingfisher API that deterministically swaps off on `.imageDidFinishLoad`. No custom override. Flow 37 capturing real photos for *some* cards from the same code path proves the swap works. |

---

## 3. Recommended next step

**Primary recommendation: treat as a Maestro-harness timing artifact and add a post-listings-load settle window to flow 01.**

This is a `team-audit` test-harness fidelity issue, not a product bug. Two options, in increasing intrusiveness:

1. **(Lowest cost — recommended)** Tighten flow 01: replace `extendedWaitUntil: visible: "Newport Beach, California"` (nav title) with `extendedWaitUntil: visible: "Top picks"` (post-data-bind), and add a 3s static settle window after `waitForAnimationToEnd`. Flow 81 (added by this task) prototypes this change without touching flow 01. If `81-hotels-loaded.png` shows real photography while `01-hotels-loaded.png` shows placeholders, hypothesis A is confirmed and flow 01 should adopt the same pattern.
2. **(Moderate cost — only if flow 81 still flakes)** App-side: wire `Kingfisher.ImagePrefetcher` into `HotelListingsView` once `loaded.hotels` arrives, prefetching the first ~6 `imageURL`s before they scroll into view. This both fixes the harness flake and improves real-world perceived performance on first listings render. This is a small, justified product improvement; would warrant a separate task.

**Document this finding** in the audit results so the screenshot is not flagged as a defect during downstream review.

---

## 4. Artifacts in this branch

- `.maestro/81-image-load-timing.yaml` — reproduction flow with stricter wait gate + 3s settle. Renders to `81-hotels-loaded.png` for A/B comparison against `01-hotels-loaded.png`.
- This report.

No source code was modified.
