# ResortPass — iOS

Two-screen iOS app for the ResortPass Founding iOS Engineer interview. Search a place, view hotel day passes there. Built with SwiftUI, hand-rolled MVI, and Swift Concurrency against the real staging API.

Architecture conventions live in [`ARCHITECTURE.md`](./ARCHITECTURE.md). Major design decisions are recorded as ADRs in [`docs/ADRs.md`](./docs/ADRs.md).

<sub>iOS&nbsp;17+ · Swift&nbsp;5.9 · 120&nbsp;unit&nbsp;tests · 81&nbsp;Maestro&nbsp;flows · 9&nbsp;ADRs · [CI&nbsp;wired](.github/workflows/ci.yml)</sub>

---

<sub>01 · SETUP</sub>

## Get it running

```bash
git clone <fork-url>
cd ResortPassApp
open ResortPass.xcodeproj
```

`Cmd+R` to build and run. `Cmd+U` to run the test suite. Build for any iPhone Simulator running iOS 17+. The `.xcodeproj` is committed alongside the `project.yml` it was generated from, so reviewers don't need XcodeGen installed.

For local convenience:

```bash
make build    # xcodebuild for iPhone 16 Pro / iOS 18
make test     # full unit suite (120 tests, ~20s)
make clean    # nuke DerivedData
```

---

<sub>02 · DEMO</sub>

## Both screens, both themes

Captured from the running app against the real staging API on iPhone 16 Pro / iOS 18.

### Light theme

| Search idle | Search loaded | Hotel listings |
|---|---|---|
| ![idle light](snapshots/01-idle.png) | ![loaded light](snapshots/02-loaded.png) | ![hotels light](snapshots/03-hotels.png) |

### Dark theme

| Search idle | Search loaded | Hotel listings |
|---|---|---|
| ![idle dark](snapshots/01-idle-dark.png) | ![loaded dark](snapshots/02-loaded-dark.png) | ![hotels dark](snapshots/03-hotels-dark.png) |

### Signature motion (videos)

Two animations are easier to feel than describe. Drop `.mov` / `.mp4` files into `docs/media/` with these names and they auto-embed below.

<video src="docs/media/morph-transition.mp4" controls width="380"></video>
<video src="docs/media/parallax-hero.mp4" controls width="380"></video>

The **morph transition**: tap a carousel card → `.matchedTransitionSource` zooms into the detail (iOS 18) or `matchedGeometryEffect` runs the same morph (iOS 17 fallback). The **parallax hero**: drag down the sticky header in detail view — the hero stretches with a damped rubber-band response driven by `CADisplayLink` at 120 Hz on ProMotion.

If video files aren't present yet, the Maestro flows reproduce the motion locally: `01-happy-path.yaml` for the morph, `15-swipe-down-dismiss-rubber-band.yaml` for the drag-throw + parallax.

---

<sub>03 · ARCHITECTURE</sub>

## How data flows

Hand-rolled MVI with `@Observable`. Each feature owns four pieces:

- **State** — struct with a nested `Status` enum (`.idle / .loading / .loaded / .empty / .failed / .failedNullCoords`). The View is a pure function of state.
- **Intent** — enum naming every action that mutates state (`queryChanged(String)`, `placeSelected(Place)`, `retryTapped`, `sceneDidBecomeActive`, …). Intents are the only way state changes.
- **ViewModel** — `@Observable @MainActor final class` exposing `private(set)` state and a synchronous `send(_:Intent)` reducer. Async work is spawned inside `Task` from the reducer; the public surface stays sync.
- **Client** — function-style `Sendable struct` of `@Sendable async throws` closures (`SearchClient`, `HotelsClient`). Injected via constructor with `.live`, `.preview`, `.failing`, `.failingThenRecovers` factory variants.

```
View → vm.send(.intent) → reducer (sync) → state mutation
                                       └→ Task { client.fetch() } → state mutation on completion
```

Every `startSearch` cancels the previous `fetchTask` before assigning a new one. The task body calls `try Task.checkCancellation()` after the debounce sleep, after `http.send`, and after `decode`. The stale-response guard (`guard query == state.query.trimmingCharacters(in: .whitespaces)`) protects against a slow response landing after the user has typed a new query.

Cancellation taxonomy: `URLSession` raises `URLError(.cancelled)` when its task is cancelled; the transport layer translates that to `CancellationError()` via `Error.translatingCancellation()` so the VM's catch arms see one uniform shape.

### The `executeJSON` transport helper

`HTTPClient.executeJSON<T>(_:as:event:payload:logger:)` owns the cross-cutting concerns that previously lived inside each feature client's `.live` closure: log-initiated, send, check cancellation, decode, check cancellation again, log-completed, translate URL-level cancellation, wrap `DecodingError` in `NetworkingError.decode`, log-failed.

Result: `SearchClient.live` and `HotelsClient.live` closures collapsed from ~25 and ~40 lines respectively to ~10 and ~15 lines — and a future third endpoint doesn't repeat any of those concerns. See [`Sources/Networking/HTTPClient.swift`](Sources/Networking/HTTPClient.swift).

### Navigation

`NavigationStack(path:)` with a value-based `AppDestination` enum. The path is bound to `state.path` via a `Binding(get:set:)` whose setter dispatches `.pathChanged([AppDestination])` — pushes (intent-triggered) and pops (swipe-back) both flow through the reducer, preserving the unidirectional invariant.

iOS 18 detail transition uses `.matchedTransitionSource` + `.navigationTransition(.zoom)`. iOS 17 falls back to `matchedGeometryEffect` + a `ZStack` overlay path. The split is gated by `ZoomTransitionIfAvailable` so the file compiles against the iOS 17 SDK.

### Why MVI (not TCA, not MVVM)

For a 2-screen take-home, TCA's framework dependency and learning surface didn't justify the cost. MVI captures the same essentials — unidirectional flow, explicit `Intent` enum, replayable transitions, sync reducer, structured concurrency for side effects — without the third-party dependency. MVVM with `@Observable` would also work, but the explicit `Intent` enum makes every state mutation discoverable in one place (the reducer's `switch`), which I prefer for testability and onboarding.

---

<sub>04 · CHOICES</sub>

## Technical choices

| Concern | Choice | Why |
|---|---|---|
| **UI framework** | SwiftUI primary, UIKit at 6 specific seams | Spec requires SwiftUI primary; UIKit drops are called out per-file in the table below with justification. |
| **Concurrency** | `async/await` + `Task` + `ContinuousClock` | `ContinuousClock.sleep(for:)` is injectable, making the 500ms debounce testable without timing flakes. Combine acceptable per spec for one operator; not worth the conceptual surface area for this codebase. |
| **Networking** | `URLSession` wrapped in `Sendable HTTPClient` struct + `executeJSON<T>` orchestration helper | Two endpoints don't need Alamofire. The wrapper centralizes status validation + injectable transport (URLProtocol-stubbable for tests). `executeJSON` absorbs logging, cancellation translation, decode-error wrapping so feature clients stay ~10 lines. |
| **State management** | Hand-rolled MVI with `@Observable` | Unidirectional flow, explicit `Intent` enum, sync reducer, structured concurrency for side effects. See **Why MVI** above. |
| **Dependency Injection** | Manual constructor injection + `AppDependencies` composition root | Each VM takes its specific client; views read shared graph via `@Environment(\.dependencies)`. One file to read for the full dependency graph. No DI container ceremony for 4 clients. See [ADR-008](docs/ADRs.md). |
| **Client shape** | Function-style: `Sendable struct` of `@Sendable async throws` closures | Test swap is one-liner: `SearchClient { _ in [] }`. No protocol-conformance ceremony per test variant. Sendable falls out for free. See [ADR-003](docs/ADRs.md) for the protocol-vs-function-style steelman. |
| **Navigation** | `NavigationStack(path:)` value-based with `AppDestination` enum | Type-safe deep-link surface. New screens add an enum case. Push and pop both flow through the reducer. |
| **Data modeling** | `Codable` with explicit `CodingKeys` (not `.convertFromSnakeCase`) | Wire has mixed-case keys (`objectID`, `queryID`, `state_code`) — `.convertFromSnakeCase` mishandles the mix. Per-type `CodingKeys` are explicit. |
| **Defensive decoding** | `FailableDecodable<T>` + `decodeLossy` / `decodeLossyArray` helpers | One malformed `Place` or `Hotel` row from the staging API drops to nil rather than nuking the whole response. Pinned by `PlaceTests.test_decodeLossy_*` and `HotelsClientLiveTests.test_search_dropsOneMalformedHotelKeepsRest`. |
| **Image caching** | Kingfisher 8.x via `CachedAsyncImage` wrapper + `EditorialGradeProcessor` | 100MB memory + ~1GB disk LRU out of the box. Editorial grade (CIFilter + Metal/MPS fallback) runs once per URL and is cached against the processor identifier. Two cache-warming windows (`warmImageCache(for:)`): listings grid (30 hotels), detail carousel (next 4 images). |
| **Minimum iOS** | 17.0 | Spec allows 16+; lifted to 17 for `@Observable`, `ContentUnavailableView`, value-based `NavigationStack(path:)`, `ContinuousClock`. See [ADR-002](docs/ADRs.md). |
| **Localization** | `String(localized:)` with `defaultValue:` for every user-visible string | ~30 calls in `Sources/Strings/Strings.swift`. Non-English catalogs not yet shipped, but `Localizable.xcstrings` would drop in cleanly. `es.lproj/Localizable.strings` exists demonstrating catalog resolution. |

### UIKit drops

SwiftUI-primary with 6 deliberate UIKit seams:

| File | UIKit surface | Why |
|---|---|---|
| `App/StatusBarBridgeHostingController.swift` | `UIHostingController` subclass exposing `preferredStatusBarStyle` | iOS 17 has no native SwiftUI API to coordinate the system status bar with a morph animation. Gated to `iOS < 18` (iOS 18's `.zoom` handles it natively). |
| `App/Transitions/Morph*.swift` (4 files) | `UIPresentationController` + `UIPercentDrivenInteractiveTransition` + `UIViewControllerAnimatedTransitioning` | Scaffolded for the iOS 17 fallback morph path. Belt-and-suspenders for the OS-version split. Optional cleanup if iOS 18 minimum gets bumped. |
| `DesignSystem/Components/FilterChipRow.swift` | `UIViewRepresentable` wrapping `CALayer` for the chip selection pulse | `CABasicAnimation` is frame-precise, vBlank-aligned — distinct from SwiftUI's transaction system. Single-frame border-width pulse that reads as a "confirmation ring." |
| `DesignSystem/Tokens/Theme.swift` | `UIScreen.main.scale` for `Theme.Spacing.hairline` | `1.0 / UIScreen.main.scale` gives a physical-pixel-crisp hairline. SwiftUI has no universally-accessible `displayScale` equivalent for token files. Single-scene app, so `UIScreen.main` works; a follow-up would inject via environment. |
| `ImageCaching/EditorialGradeProcessor.swift` | `UIImage` + `MTKTextureLoader` + Core Image / MPS | Kingfisher's `ImageProcessor` protocol takes `UIImage`. Runs the editorial grade (saturation + contrast lift + warm shift) on cache-miss. Core Image path + Metal/MPS fallback both present. |
| `Features/HotelDetail/HotelDetailScene.swift` | `CADisplayLink` snap-back driver | Drag-throw rubber-band interpolates at the native display refresh (120 Hz on ProMotion). SwiftUI's spring would work too; the CADisplayLink path is documented as a deliberate supplemental driver in [ADR-007](docs/ADRs.md). |

### Typed primitives in the networking layer

Cross-cutting type-safety wins that replaced raw strings and `[String: Any]`:

| Was | Now | File |
|---|---|---|
| `request.httpMethod = "GET"` | `request.setMethod(.get)` via `enum HTTPMethod` | [`HTTPMethod.swift`](Sources/Networking/HTTPMethod.swift) |
| `request.setValue("application/json", forHTTPHeaderField: "Content-Type")` | `request.setContentType(.json)` via `enum HTTPHeader` + `enum ContentType` | [`HTTPMethod.swift`](Sources/Networking/HTTPMethod.swift) |
| `[String: Any]` POST body + `JSONSerialization` | `AlgoliaHotelsRequest: Encodable` + `Encoders.api` | [`HotelsClient.swift`](Sources/Networking/HotelsClient.swift) |
| Raw event strings (`"search.initiated"`) | `LogEvent` enum + `LogClient` overloads | [`LogEvent.swift`](Sources/Logging/LogEvent.swift) |
| `final class CallCounter: @unchecked Sendable` + `NSLock` | `actor CallCounter` | [`CallCounter.swift`](Sources/Networking/CallCounter.swift) |
| `enum APIEnvironment { case staging }` | `struct APIEnvironment` with `static let staging` (room for `.production`) | [`APIEnvironment.swift`](Sources/Networking/APIEnvironment.swift) |
| Two duplicated 5-arm `message(for:ErrorKind)` switches in the VMs | `struct ErrorMessages` + `Strings.{Search,Hotels}.errorMessages` factories | [`ErrorKind.swift`](Sources/Networking/ErrorKind.swift) |

---

<sub>05 · FEATURES</sub>

## What each feature owns

### Search

[`Sources/Features/Search/`](Sources/Features/Search/) · [`SearchClient.swift`](Sources/Networking/SearchClient.swift)

| | |
|---|---|
| **State** | `SearchState` with 6 statuses incl. `failedNullCoords` |
| **Key choice** | 500ms debounce via injected `ContinuousClock` — testable, no sleep-flakes |
| **Edge case** | Brooklyn FL (null coords from real API) → dedicated `.failedNullCoords` state with "Search a nearby city" CTA. No "Try Again" loop trap. |
| **Maestro find** | F12-05 (landscape keyboard occluded retry CTA) — fixed via `.scrollDismissesKeyboard(.immediately)` + `onChange(of: state.status)` |
| **Tests** | 11 VM tests + 21 spec compliance + 6 live-client tests |

### Hotel listings

[`Sources/Features/HotelListings/`](Sources/Features/HotelListings/) · [`HotelsClient.swift`](Sources/Networking/HotelsClient.swift)

| | |
|---|---|
| **State** | `HotelListingsState` with nested `PresentationLayer`, `Status`, `Loaded` (incl. `fetchedAt`, `sections`), `Section`, `Filter` |
| **Section pipeline** | `Loaded.buildSections(hotels:activeFilter:)` — pure section builder: Top picks (≤5 by rating), Within walking distance (≤1.5mi), Best value (cheapest 5), All (fallback). Cached as `private(set) var sections`; rebuilt only on `hotels`/`activeFilter` mutation. |
| **Filters** | `.all / .pool / .spa / .adults / .pets / .wellness` — string-match heuristic against `productName + primaryVibe` |
| **Cache warming** | `warmImageCache(for:)` — listings grid (first 30) on `.loaded`, detail carousel (next 4 images) on `.cardTapped` |
| **Spec deviation** | Sectioned horizontal carousels (not vertical list). Documented in [ADR-009](docs/ADRs.md) — see **Hotel listings rendering** below. |
| **Tests** | 5 VM tests + 11 sections tests + 9 live-client tests |

### Hotel detail

[`Sources/Features/HotelDetail/HotelDetailScene.swift`](Sources/Features/HotelDetail/)

| | |
|---|---|
| **Morph** | iOS 18: `.matchedTransitionSource` + `.navigationTransition(.zoom)`. iOS 17: `matchedGeometryEffect` + ZStack overlay. Gated by `ZoomTransitionIfAvailable` modifier. |
| **Drag-throw dismiss** | `CADisplayLink`-driven spring integrator at 120 Hz on ProMotion. Rubber-band response with snap-back. Pinned by `15-swipe-down-dismiss-rubber-band.yaml`. |
| **Parallax hero** | Sticky header stretches on pull-down. `StretchyHero`-style modifier with damped scale. |
| **Image carousel** | `HotelImageCarousel` with peek + mid-snap behavior, processor-aware caching. |

---

<sub>06 · DATA</sub>

## Real API quirks worth knowing

The staging API has real-world rough edges that shaped the model layer:

- **Autocomplete is a top-level array** — not wrapped in `{"results": [...]}`. `Decoders.api.decodeLossy([Place].self, from: data)` handles it directly.
- **Some places have `latitude: null, longitude: null`** (e.g., "Brooklyn, Florida"). Tapping such a place would send `0,0` to the hotels endpoint and get unrelated results. `Place.hasUsableCoordinates` + the VM guard + a dedicated `.failedNullCoords` state surface the dead-end honestly. `HotelsClient.live` also has a `precondition` on coordinates so the contract is enforced at the transport seam.
- **Integer `id` collisions.** Newport Beach and Newport Coast both have `id=236` because Coast is an alias. `objectID` (denormalized string key) is stable; `Place.id` (`Identifiable`) maps to it so `ForEach` doesn't silently drop duplicates.
- **Hotel response shape.** `currency` is a nested object with `iso_code`; `image[]` is an array of `picture.url` / `picture.results.url` / `picture.details.url` (decoder prefers the largest); both `rating` (4.4-style) and `avg_rating` (often 0.0) ship — the decoder uses `rating`. Cheapest price is `products[].price.min()`.
- **Lossy array decode by default.** `FailableDecodable<T>` + `decodeLossyArray` lets one bad row drop without nuking the rest of the response. Pinned across `PlaceTests` and `HotelsClientLiveTests`.

---

<sub>07 · TESTING</sub>

## Verification at two layers

```
unit:    120 tests across 12 files · ~20s · iPhone 16 Pro / iOS 18
maestro: 81 flows · real staging API · launch-arg-injected failure variants
```

### Unit tests (120 total)

| Suite | Count | What it pins |
|---|---|---|
| `SearchViewModelTests` | 11 | Reducer behavior — every status transition, debounce, cancellation, stale-response guard |
| `HotelListingsViewModelTests` | 5 | Fetch lifecycle, retry, location-routing |
| `SpecComplianceTests` | 21 | Interview-spec pinning: 500ms debounce timing, dismiss-no-refetch, scenePhase staleness, presentation transitions |
| `HTTPClientTests` | 7 | URLProtocol-stubbed transport: status mapping, non-HTTP, network unavailable, cancellation cascade |
| `NetworkingLayerTests` | 18 | `Endpoints` URL verbatim vs spec (incl. CJK + percent-encoding) + every `ErrorKind` mapping |
| `NetworkingConstantsTests` | 8 | Direct pins for `successStatusRange` boundaries, `requestTimeout`, page sizes, debounce, staleness threshold |
| `SearchClientLiveTests` | 6 | URL build, lossy decode, error propagation, cancellation translation against the actual `.live` factory |
| `HotelsClientLiveTests` | 9 | Body shape via stubbed `HTTPClient`, POST + Content-Type, wire-to-domain mapping, fallbacks |
| `LogClientTests` | 3 | `.silent` discards, custom factory captures, `LogEvent` overload dispatch |
| `HotelListingsSectionsTests` | 11 | Section pipeline: top-picks cap, walking ≤ 1.5mi boundary, best-value ordering, fallback All, filter integration |
| `PlaceTests` | 15 | Decoding real Newport/Brooklyn fixtures + adversarial inputs + `FailableDecodable` lossy coverage |
| `HotelTests` | 6 | Custom decoder coverage + Codable round-trip |

Run with `make test` or `Cmd+U` in Xcode.

### Maestro flows (81 total) — what each band covers

| Band | Range | Coverage |
|---|---|---|
| **State cycles** | 01–11 | Happy path · empty/clear/rapid-typing · null-coord guard · CJK input · landscape · failed-then-retry (search + hotels) · hotels empty · row-field verification · visual audit |
| **Animation audits** | 12–21 | Stretchy hero · transitions · morph spring envelope · swipe-down dismiss (rubber-band + 200pt commit) · search pill blur · peek carousel mid-snap · filter chip mid-transition · hero stretch pulldown · content fade-in detail |
| **Filter chips** | 22–27 | Spa · Adults · Pets · Wellness · empty result · reset |
| **Retry recoveries** | 28–29 | Search-retry-failed · hotels-retry-failed (uses `--ui-test-toggle-recovery-on-retry`) |
| **Loading skeletons** | 30–31 | Search · hotels |
| **Dark mode** | 32–41 | Idle · loaded · empty · failed · null-coords · hotels-loaded · hotels-empty · hotels-failed · detail-expanded · empty-filter |
| **XXL Dynamic Type** | 42–46 | Idle · loaded · hotels-loaded · empty-filter · failed |
| **Landscape coverage** | 47–53 | Search empty/failed/null-coords · hotels empty/failed · detail-expanded · empty-filter |
| **German locale** | 54–56 | de-DE idle · failed-truncation · hotels-loaded (verifies long-string truncation) |
| **Orphan-code regression** | 58–61 | Verifies deleted UI surfaces (HotelCard, SearchActiveOverlay, recent searches, curated destinations) are not mounted |
| **Edge cases** | 62–67 | Pull-to-refresh (currently disabled, flow pins absence) · rapid-type-then-clear · debounce-window-collision · offline-search · offline-hotels · slow-3G-image-loading |
| **VoiceOver** | 68–70 | Search idle · hotel row · detail close |
| **Reduce Motion / Bold Text / Increase Contrast / AX5** | 71–77 | Card tap · parallax hero · filter chip · eyebrow truncation · place row contrast · AX5 search idle + hotels loaded |
| **iPad** | 78–79 | Hotels-loaded · detail-expanded (out of spec but flow-verified) |
| **Coordinate-tap + image timing** | 80–81 | System back-button regression · image-load timing |

### How Maestro is wired here

- **Launch-arg-injected client variants** in `ResortPassApp.init`: `--ui-test-fail-search`, `--ui-test-fail-hotels`, `--ui-test-empty-hotels`, `--ui-test-toggle-recovery-on-retry`. Maestro exercises every failure UI without disrupting staging.
- **Assertion model.** Flows use `assertVisible:` against real on-screen text the user sees, `extendedWaitUntil:` with timeouts for async UI, `takeScreenshot:` at named checkpoints, and `waitForAnimationToEnd:` for spring-paced sequences. Maestro's runner exits non-zero on any failed assertion or app crash — the flow IS the test. No separate output-comparison harness needed.
- **Run locally** (Java prerequisite for Maestro):
  ```bash
  export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
  maestro test .maestro/01-happy-path.yaml          # one flow
  maestro test .maestro/                            # the full 81
  ```

### Three real bugs Maestro caught

#### F12-05 — Landscape keyboard occluded the retry CTA

`.maestro/06-landscape.yaml` flagged that in compact-height layouts, the on-screen keyboard hid the "Try Again" button in `.failed` / `.empty` states. Fix: `.scrollDismissesKeyboard(.immediately)` on the search view + `onChange(of: state.status)` to resign first responder when entering those statuses. Lives in [`SearchView.swift:24-36`](Sources/Features/Search/SearchView.swift).

#### iOS 26 + Maestro 2.5.1 — empty accessibility tree

`assertVisible: "Where are you headed?"` failed on iOS 26.4 but passed on iOS 18 with the same build. Investigation: Maestro 2.5.1 cannot walk the iOS 26 SwiftUI accessibility hierarchy — every body `Text` view is missing from the tree, only navigation chrome reaches the assertion layer. The app renders identically on both visually. **Tooling pin: target iPhone 16 Pro / iOS 18** for all Maestro work until Maestro ships iOS 26 support.

#### Null-coordinate dead-end

`01-happy-path.yaml` + `05-null-coords-guard.yaml` together pinned that selecting "Brooklyn, Florida" (lat/lng `null` in the API) surfaces the dedicated `.failedNullCoords` state with a "Search a nearby city" CTA — not a generic "Try Again" loop that would re-pick the same offending place. Both the UI guard and the `HotelsClient.live` `precondition` enforce it.

### Snapshot testing

Not implemented in this submission. Listed in **With more time** below — `swift-snapshot-testing` for the state × portrait/landscape × light/dark matrix would close the visual-regression gap that Maestro's text-assertion model can't directly cover.

---

<sub>08 · AUTOMATION</sub>

## Continuous Integration

GitHub Actions workflow at [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Three jobs:

| Job | Trigger | Duration | What it gates |
|---|---|---|---|
| **`unit-tests`** | Every push + PR | ~5 min | Full 120-test suite on iPhone 16 Pro / iOS 18 sim |
| **`maestro-smoke`** | Every push + PR (after `unit-tests`) | ~5–10 min | Critical flows: `01-happy-path`, `06-landscape`, `02-search-empty`, `09-hotels-empty`, `07-search-failed-retry` |
| **`maestro-full`** | Weekly schedule (Mon 09:00 UTC) + manual dispatch | ~30–40 min | All 81 Maestro flows |

`xcresult` bundles and Maestro screenshots upload as workflow artifacts on failure. Concurrency control cancels in-progress runs when a new commit lands on the same ref.

**Maestro in CI uses the same fail-on-missed-assertion model as locally** — no separate diff/compare infrastructure. Flows hit the real staging API; a staging outage will fail CI, which is the accepted trade-off for high-fidelity coverage. The workflow's top comment documents this.

---

<sub>09 · DECISIONS</sub>

## What earned an ADR

Nine decisions warranted a written record. Full text in [`docs/ADRs.md`](docs/ADRs.md).

| | Decision | Why it earned an ADR |
|---|---|---|
| **ADR-001** | Hand-rolled MVI, not TCA | Framework cost > value at N=2 screens; unidirectional flow + explicit Intent enum captures the essentials without ceremony. |
| **ADR-002** | iOS 17 deployment target (spec floor is 16) | `@Observable`, `ContentUnavailableView`, value-based `NavigationStack(path:)`, `ContinuousClock` — each iOS-17-only API saves 30–60 LOC of `#available` branching. |
| **ADR-003** | Function-style clients, not protocols | At N=1 operation per client, protocols add ceremony with no payoff. Test swap is one-liner. Sendable + `@Sendable` closures pair cleanly with Swift Concurrency. Includes a 3-way steelman vs the generic-Endpoint approach. |
| **ADR-004** | Sweep I (parallax GeometryReader → background+PreferenceKey) reverted | The replacement passed math but interacted badly with `.scaledToFill` on the hero, biasing scroll content width. GeometryReader's perf cost back. |
| **ADR-005** | Dismiss-no-refetch guard | Status-gated `.appeared` prevents skeleton flash on pop-back from detail; `.retryTapped` stays unconditional. Pinned by `SpecComplianceTests.test_hotelListings_appearedWhenAlreadyLoaded_doesNotRefetch`. |
| **ADR-006** | scenePhase staleness policy — 5-minute threshold | Balances "briefly switched to Messages" (no refetch) vs "came back hours later" (real stale-data risk). Constant centralized for future tuning. |
| **ADR-007** | Value-bound animation, not `PhaseAnimator` | iOS 18 `.navigationTransition(.zoom)` re-instantiates the destination view; `PhaseAnimator`'s internal phase index resets while the `@State` trigger is preserved → content stuck at phase 0. Value-binding has no internal state to desync. |
| **ADR-008** | `AppDependencies` composition root | One file, full dependency graph. Tests swap at the VM boundary; views read via `@Environment(\.dependencies)`. Default value is `.preview` so SwiftUI Previews never accidentally hit staging. |
| **ADR-009** | Sectioned horizontal carousels for Hotel Listings | Hospitality search is image-led; spec's vertical list forfeits the curation signal that differentiates a day-pass marketplace. Each card still surfaces name + image + rating + price per spec. |

---

<sub>10 · STRUCTURE</sub>

## Project layout

```
Sources/
├── App/
│   ├── ResortPassApp.swift               @main entry + DEBUG launch-arg overrides
│   ├── AppDependencies.swift             composition root + Environment plumbing
│   ├── StatusBarBridgeHostingController.swift   iOS-17-only status-bar coordinator
│   └── Transitions/Morph*.swift          4 files — iOS 17 fallback morph adapters
├── Models/
│   ├── Place.swift / Hotel.swift / Currency.swift
│   └── Place+PreviewFixtures.swift, Hotel+PreviewFixtures.swift
├── Networking/
│   ├── HTTPClient.swift                  Sendable transport + executeJSON<T> orchestration helper
│   ├── HTTPMethod.swift                  HTTPMethod / HTTPHeader / ContentType enums + URLRequest helpers
│   ├── SearchClient.swift, HotelsClient.swift   function-style clients
│   ├── Endpoints.swift                   typed URL builders
│   ├── APIEnvironment.swift              struct with .staging factory
│   ├── Constants.swift                   debounce window, page sizes, status range, staleness threshold
│   ├── Decoders.swift                    Decoders.api + Encoders.api factories
│   ├── ErrorKind.swift                   error taxonomy + ErrorMessages + isRetryable
│   ├── FailableDecodable.swift           lossy array decode helpers
│   └── CallCounter.swift                 actor — used by .failingThenRecovers variants
├── Features/
│   ├── Search/                           State + Intent + ViewModel + View
│   ├── HotelListings/                    State + Intent + ViewModel + View (incl. section pipeline)
│   └── HotelDetail/                      HotelDetailScene.swift — pushed-mode + CADisplayLink drag-throw
├── DesignSystem/
│   ├── Tokens/Theme.swift                Palette → Theme tokens (Color / Spacing / CornerRadius / Animation / Icon / Typography)
│   └── Components/                       CompactHotelCard · FilterChipRow · HotelImageCarousel · StarRating · CardPressStyle · BrandedImagePlaceholder · AllComponentsCatalog
├── ImageCaching/
│   ├── CachedAsyncImage.swift            Kingfisher integration wrapper
│   └── EditorialGradeProcessor.swift     CIFilter + Metal/MPS fallback
├── Logging/
│   ├── LogClient.swift                   function-style logger (debug/info/error)
│   └── LogEvent.swift                    typed event names
├── Routing/AppDestination.swift          single value-based destination enum
├── Strings/Strings.swift                 String(localized:) namespace + ErrorMessages factories
└── Resources/Assets.xcassets             AppIcon + Colors/ (semantic colorsets) + Fonts/

Tests/
├── Search/HotelListings*ViewModelTests   reducer behavior per feature
├── SpecComplianceTests                   spec-pinning (debounce timing, dismiss-no-refetch, staleness, transitions)
├── *ClientLiveTests                      direct .live factory coverage via stubbed HTTPClient
├── HTTPClientTests                       URLProtocol-stubbed transport
├── NetworkingLayerTests                  Endpoints + ErrorKind mapping
├── NetworkingConstantsTests              direct constant pins (boundaries)
├── HotelListingsSectionsTests            section builder pipeline
├── LogClientTests                        logging surface
├── PlaceTests / HotelTests               decoder coverage incl. real fixtures
└── Fixtures/                             real staging JSON (places-newport, places-brooklyn, hotels-newport)
```

---

<sub>11 · ACCESSIBILITY</sub>

## Accessibility posture

- VoiceOver labels on every interactive element (search bar, place rows, retry buttons, system back).
- Hotel cards use `.accessibilityElement(children: .combine)` so the rotor reads each card as a single element (`Strings.Accessibility.hotelRowLabel` composes name + rating + distance + price).
- Section headers carry `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isHeader)` so VoiceOver users can rotor-skim section by section.
- Dynamic Type respected via semantic font styles (`.caption2`, `.footnote`, `.subheadline`, `.body`, etc.) — layouts scale through `xxLarge` and into the accessibility sizes. SF Symbol icons retain fixed sizes for visual centering. Pinned by Maestro flows `42–46` (XXL) and `76–77` (AX5).
- `ContentUnavailableView` for empty + failed states (iOS 17 native component with built-in traits).
- Light/dark mode via Asset Catalog colorsets (`Sources/Resources/Assets.xcassets/Colors/`) with `Any Appearance` + `Dark Appearance` variants. WCAG AA verified on light; dark contrast not formally audited.

### Touch-target audit (informal)

- Filter chip tap area is ~32pt before padding lifts to ~44pt — on the HIG minimum boundary.
- Clear-search button's icon is ~12pt within a ~30pt container — marginal.

Flagged for a future explicit audit pass.

### Honest limitations

- No `AccessibilitySnapshot` integration for label/trait regression catching (deferred).
- No automated VoiceOver navigation-order tests beyond Maestro flows `68–70`.
- AX5 (largest accessibility size) verified visually via Maestro only; no per-component layout audit.

---

<sub>12 · DEVIATION</sub>

## Hotel listings rendering — deliberate deviation

The interview prompt suggests *"vertical list (e.g., `List` or `LazyVStack` inside a `ScrollView`)"* for Screen 2. This app ships **sectioned horizontal carousels** (`Top picks` · `Within walking distance` · `Best value` · `All`) on a vertical scroll instead. Three reasons:

- Hospitality search is image-led. Wide, photo-dominant cards in a peek-carousel give every result equal first-class visual real estate — the rhythm of 2026-era travel apps (Airbnb, Hopper, Booking.com).
- Sectioning by editorial axis (`Top picks` / `Within walking distance`) foregrounds curation, which is what differentiates a day-pass marketplace from a generic hotel directory.
- A pure vertical list is the strictly compliant choice; this deviation prioritizes UX impression over verbatim spec adherence, which felt like the right founding-engineer call to surface explicitly.

Each card surfaces hotel name, image, rating, and price — the spec's *"most relevant product/price information"* — so the information surface matches even when the layout doesn't. Documented in [ADR-009](docs/ADRs.md).

---

<sub>13 · LIMITATIONS</sub>

## Known limitations

- **Pagination** — both endpoints accept `limit` + `offset`; the UI doesn't paginate yet. With 30 hotels per page from the algolia endpoint, infinite scroll would be a natural addition.
- **Pull-to-refresh** on hotel listings is currently disabled (pinned by Maestro flow `62-pull-to-refresh-hotels`).
- **Offline behavior** — no caching of last-seen results; a network drop returns the user to `.failed` without a stale-data fallback.
- **Localization** — `String(localized:)` plumbing is in place (~30 calls). Non-English `.xcstrings` catalogs not yet shipped; `es.lproj/Localizable.strings` exists demonstrating resolution but is not a full translation.
- **Extended product surface** — each hotel has multiple products with tiered prices; the UI shows only the cheapest price + top-level product name.
- **App icon + launch screen** — placeholder `Contents.json` only; no actual icon graphics.
- **Snapshot testing** — not implemented in this submission (see below).
- **iOS 26 + Maestro** — Maestro 2.5.1 can't walk the iOS 26 accessibility tree; all Maestro work pinned to iOS 18 sim until resolved upstream.
- **Recording infrastructure** — `xcrun simctl io booted recordVideo` returns `SimRenderServer error 2` on Xcode 26 / iOS 26. Static screenshots work; animated demos for the morph + parallax require QuickTime manual recording (drop `.mov` files into `docs/media/`).

---

<sub>14 · NEXT</sub>

## With more time

Ordered roughly by interview-lens value-per-hour:

1. **Pull-to-refresh + pagination** on hotel listings via `refreshable {}` + offset bumping. Tests: VM state for `.loadingMore`, infinite-scroll trigger threshold, end-of-results signal. ~2–3 h.
2. **Snapshot test suite** — `swift-snapshot-testing` across `idle / loading / loaded / empty / failed` × Search + Listings × portrait/landscape × light/dark = ~40 baselines. `AccessibilitySnapshot` for label/trait regression catching on top. ~3–4 h.
3. **Migration past N=4 endpoints** — generic `Endpoint<Response>` + `APIClient.send(_:)` dispatcher (sketched in [ADR-003](docs/ADRs.md)). Centralizes retry, auth, telemetry. Not protocols — those don't fix the right problem.
4. **Swift 6 typed throws** — `func search(_:) async throws(SearchError) -> [Place]` so `ErrorKind.from` doesn't need downcasts.
5. **`AsyncSequence` debounce** via Async Algorithms (vs current imperative `Task` + `clock.sleep`). Replaces the existing 500ms guard with a more declarative stream.
6. **Maestro matrix in CI** — `maestro-full` currently runs on schedule only. Wire matrix configs in CI to cover iPhone SE / 15 / 17 Pro Max + portrait/landscape on PRs.
7. **Snapshot test integration in CI** — fourth workflow job: snapshot regression on PRs with diff images uploaded as artifacts.
8. **`LogClient.recording` factory** that buffers calls so unit tests can assert on logger emissions per Status transition.
9. **Pre-commit hooks** (SwiftFormat or SwiftLint) so the conventions documented here can't drift.
10. **Localization catalogs** for at least Spanish and French — `String(localized:)` plumbing in place, only `.xcstrings` data missing.
11. **Performance traces** for the morph hot path (Instruments time-profile + a target frame budget pinned in CI).
12. **iOS 26 retest** once Maestro fixes the accessibility-tree gap documented above.
13. **`simctl recordVideo` workaround** — wire QuickTime recording or `ffmpeg avfoundation` with Screen Recording permission so the morph + parallax demos can ship as real video in `docs/media/`.

---

<sub><a href="ARCHITECTURE.md">ARCHITECTURE.md</a> · <a href="docs/ADRs.md">docs/ADRs.md</a> · <a href=".github/workflows/ci.yml">CI workflow</a> · <a href=".maestro/">Maestro flows</a></sub>
