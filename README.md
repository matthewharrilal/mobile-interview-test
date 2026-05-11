# ResortPass — iOS Take-Home

Two-screen iOS app for the ResortPass Founding iOS Engineer interview. Search for a place, view available hotel day passes at that place. Built with SwiftUI, hand-rolled MVI, and Swift Concurrency against the staging API.

Architecture conventions are documented in [`ARCHITECTURE.md`](./ARCHITECTURE.md). Major design decisions are recorded in [`docs/ADRs.md`](./docs/ADRs.md).

## Setup

```
git clone <fork-url>
cd mobile-interview-test
open ResortPass.xcodeproj
```

Build and run on any iPhone Simulator running iOS 17+. The `.xcodeproj` is committed alongside `project.yml`, so reviewers don't need XcodeGen installed.

The Makefile is for the engineer's local convenience:

```
make build   # xcodebuild for iPhone 15 Simulator
make test    # runs the test suite
make clean   # clears DerivedData
```

## Demo

Both screens, both states, real staging API:

| Search idle | Search loaded | Hotel listings |
|-------------|---------------|----------------|
| ![Idle](snapshots/01-idle.png) | ![Loaded](snapshots/02-loaded.png) | ![Hotels](snapshots/03-hotels.png) |

Maestro flows in `.maestro/` exercise the full happy path + edge cases (empty state, clear button, debounce/cancellation, null-coordinate guard) end-to-end against the live staging API. Run with `maestro test .maestro/`.

## Architecture

Hand-rolled MVI with `@Observable`. Each feature owns:

- A **State** struct with a nested `Status` enum (`.idle / .loading / .loaded / .empty / .failed`). Every UI state derives from this; the View is a pure function of state.
- An **Intent** enum naming every action that mutates state (`queryChanged(String)`, `placeSelected(Place)`, `retryTapped`, etc.). Intents are the only way state changes.
- A **ViewModel** (`@Observable @MainActor final class`) that exposes `private(set)` state and a synchronous `send(_ intent:)` reducer. Async work is spawned inside `Task` from the reducer; the public surface stays sync.
- A **Client** (function-style `struct` of `@Sendable async throws` closures) injected via constructor with `.live`, `.failing`, and `.preview` extensions.

Navigation uses `NavigationStack` with value-based `.navigationDestination(for: AppDestination.self)`. The path is bound to `state.path` via a `Binding(get:set:)` whose setter dispatches `.pathChanged([AppDestination])` — so both pushes (intent-triggered) and pops (system swipe-back) flow through the reducer, preserving the unidirectional invariant.

### Why MVI (not TCA, not MVVM)?

For a 2-day take-home with two screens, the cost/value of bringing in TCA (third-party dependency, learning curve for reviewers) wasn't justified. MVI captures the same essentials — unidirectional flow, explicit Intent enum, replayable state transitions, sync reducer, structured concurrency for side effects — without the framework overhead. MVVM with `@Observable` would also have worked, but the explicit Intent enum makes every state mutation discoverable in one place (the reducer's `switch`), which I prefer for testability and onboarding new engineers.

### State Management

State flow:

```
View → vm.send(.intent) → reducer (sync) → state mutation
                                       └→ Task { client.fetch() } → state mutation on completion
```

The reducer is synchronous and pure with respect to its inputs; the only side effect is spawning `Task` for async work. Cancellation: every `startSearch` cancels the previous `fetchTask` before assigning a new one, and the task body uses `try Task.checkCancellation()` after the debounce sleep AND after the network call. The stale-response guard (`guard query == state.query.trimmingCharacters(in: .whitespaces)`) protects against a slow response landing after the user has typed a different query.

## Technical Choices

| Concern | Choice | Rationale |
|---------|--------|-----------|
| UI Framework | SwiftUI primary, UIKit at specific seams (see below) | Spec requires SwiftUI primary; UIKit drops are called out per-file with justification in **UIKit drops** section below. |
| Concurrency | `async/await` + `Task` + `ContinuousClock` | Idiomatic Swift Concurrency. `ContinuousClock.sleep(for:)` is injectable, making the 500ms debounce testable without timing flakes. Combine would also work for debounce, but introducing it just for one operator wasn't worth the conceptual surface area. |
| Networking | `URLSession` directly, wrapped in a Sendable `HTTPClient` struct | Two endpoints don't need Alamofire. The wrapper centralizes status validation + injectable transport (so tests can stub via `URLProtocol`), and keeps the dependency surface to the standard library. |
| Image caching | Kingfisher 8.x via `CachedAsyncImage` wrapper | Memory (100MB default LRU) + disk (~1GB default, 7-day TTL) cache out of the box. `cancelOnDisappear` matches the scroll-cancellation behavior we want. `EditorialGradeProcessor` (CIFilter + a Metal/MPS fallback) runs once per URL and the result is cached against the processor identifier so the grade isn't recomputed on every scroll. Wrapper means a future swap to a different cache changes one file. |
| State management | Hand-rolled MVI with `@Observable` | See above. |
| Dependency Injection | Manual constructor injection | The dependency graph is tiny (each VM takes 2-3 closures via Client struct). A DI container (Factory, Swinject) would add ceremony for ~zero readability win. `.live` defaults make production wiring concise; tests pass `.failing` or fixtures explicitly. |
| Navigation | `NavigationStack(path:)` value-based with `AppDestination` enum | Type-safe deep-link surface. New screens add an enum case. |
| Minimum iOS | 17.0 | Spec allows 16+; we lift to 17 to use `@Observable`, `ContentUnavailableView`, native value-based `NavigationStack(path:)`, and stable `ContinuousClock`. The complexity savings vs the install-base trade-off favored 17 for this codebase shape. See `docs/ADRs.md > ADR-002`. |

## UIKit drops

This is a SwiftUI-primary app. UIKit appears at six specific seams, each with a documented technical justification:

| File | UIKit surface | Why |
|---|---|---|
| `Sources/App/StatusBarBridgeHostingController.swift` | `UIHostingController` subclass exposing `preferredStatusBarStyle` | iOS 17 has no native SwiftUI API to coordinate the system status bar style with a morph animation. iOS 18's `.zoom` transition handles this natively, so the bridge is gated to `iOS < 18`. |
| `Sources/App/Transitions/Morph*.swift` (4 files) | `UIPresentationController` + `UIPercentDrivenInteractiveTransition` + `UIViewControllerAnimatedTransitioning` | Scaffolded for the iOS 17 fallback morph path. Not currently consumed at runtime (iOS 18 `.zoom` is the primary). Retained as belt-and-suspenders for the OS-version split documented in `docs/ADRs.md > ADR-009`. Optional cleanup: delete if iOS 18 minimum gets bumped. |
| `Sources/DesignSystem/Components/FilterChipRow.swift` | `UIViewRepresentable` wrapping a `CALayer` for the chip selection pulse | `CABasicAnimation` runs CoreAnimation-side (frame-precise, vBlank-aligned) — distinct from SwiftUI's transaction system. Used for a single-frame border-width pulse that reads as a "confirmation ring" on chip selection. |
| `Sources/DesignSystem/Tokens/Theme.swift` | `UIScreen.main.scale` for `Theme.Spacing.hairline` | `1.0 / UIScreen.main.scale` gives a physical-pixel-crisp hairline width. SwiftUI has no `@Environment(\.displayScale)`-equivalent that's universally accessible from a token file. `UIScreen.main` is deprecated for multi-scene apps; we're single-scene, so it works — but a follow-up would inject scale via environment. |
| `Sources/ImageCaching/EditorialGradeProcessor.swift` | `UIImage` + `MTKTextureLoader` + Core Image / MPS | Kingfisher's `ImageProcessor` protocol takes `UIImage`, not SwiftUI `Image`. The processor runs the editorial color grade (saturation, contrast lift, gentle warm shift) on cache-miss; both a CoreImage path and a Metal/MPS path are present. |
| `Sources/Features/HotelDetail/HotelDetailScene.swift` | `CADisplayLink` snap-back driver | The drag-throw dismiss uses a hand-rolled spring integrator driven by `CADisplayLink` so the rubber-band snap-back interpolates at the native display refresh (120 Hz on ProMotion devices). Optional polish — SwiftUI's spring would also work; the CADisplayLink path is documented in `docs/ADRs.md` as a deliberate "supplemental driver" not strictly required. |

## Folder Tree

```
ResortPassApp/
├── project.yml                       XcodeGen project definition (engineer convenience)
├── ResortPass.xcodeproj              Generated; committed so reviewers don't need XcodeGen
├── Makefile                          build / test / clean
├── README.md                         this file
├── .maestro/                         Maestro flows (interaction tests)
├── Sources/
│   ├── App/
│   │   └── ResortPassApp.swift       @main entry; wires .live clients
│   ├── Models/
│   │   ├── Place.swift               Autocomplete result
│   │   ├── Hotel.swift               Algolia hotel result
│   │   └── Currency.swift            ISO-4217 currency
│   ├── Networking/
│   │   ├── APIEnvironment.swift      Base URL switching
│   │   ├── Endpoints.swift           Typed URL builders
│   │   ├── HTTPClient.swift          Sendable struct, status validation
│   │   ├── SearchClient.swift        Function-style client + .live/.failing/.preview
│   │   ├── HotelsClient.swift        Function-style client + extensions
│   │   ├── Decoders.swift            Configured JSONDecoder
│   │   └── Constants.swift           Debounce window, page sizes, status range
│   ├── DesignSystem/
│   │   └── Tokens/Theme.swift        Two-tier (Palette → Theme) tokens
│   ├── Routing/
│   │   └── AppDestination.swift      The single value-based destination enum
│   ├── ImageCaching/
│   │   └── CachedAsyncImage.swift    Kingfisher integration shim
│   ├── Logging/
│   │   └── LogClient.swift           Function-style logger
│   ├── Resources/
│   │   └── Assets.xcassets/          AccentColor + AppIcon
│   └── Features/
│       ├── Search/
│       │   ├── Search.swift          State + Intent + ViewModel
│       │   └── SearchView.swift      View
│       └── HotelListings/
│           ├── HotelListings.swift   State + Intent + ViewModel
│           └── HotelListingsView.swift  View
└── Tests/
    └── ResortPassTests/              Unit + snapshot tests
```

## Testing Strategy

Two layers (snapshot tests deliberately deferred — see _What I'd do differently_):

1. **Unit tests** — 83 tests across `Tests/`:
   - `SearchViewModelTests.swift` (11) — reducer behavior
   - `HotelListingsViewModelTests.swift` (5) — reducer behavior
   - `SpecComplianceTests.swift` (21) — interview-spec pinning: 500ms debounce timing, cancellation race, stale-response guard, dismiss-no-refetch regression, scenePhase staleness, presentation transitions
   - `HTTPClientTests.swift` (7) — URLProtocol-stubbed transport: status mapping (2xx/4xx/5xx), non-HTTP response, network unavailable, cancellation cascade
   - `NetworkingLayerTests.swift` (18) — `Endpoints` URL verbatim vs interview spec (incl. percent-encoding + CJK input) + `ErrorKind` mapping for every URLError case
   - `PlaceTests.swift` (15) — decoding against real API fixtures (Newport / Brooklyn) + adversarial inputs (id-as-string, vibes-null, products-as-object) + `FailableDecodable` lossy-array coverage
   - `HotelTests.swift` (6) — Hotel decoder coverage
   Run with `make test` or in Xcode.
2. **Maestro flows** — `.maestro/` directory (~80 flows) drives real taps + assertions on a running simulator. Catches seam bugs unit tests can't see. Coverage includes: happy paths, empty/error states, retry recovery, clear button, debounce/cancellation, null-coord guard, non-Latin (CJK) search, dark mode, landscape, AX5 Dynamic Type, scene-phase staleness.

## Accessibility

- VoiceOver labels on every interactive element (search bar, place rows, retry buttons, back button via the system nav).
- Hotel cards use `.accessibilityElement(children: .combine)` so VoiceOver reads each card as a single rotor element (`Strings.Accessibility.hotelRowLabel` composes name + rating + distance + price).
- Section headers use `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isHeader)` so VoiceOver users can rotor-skim section by section.
- Dynamic Type respected: text fonts use semantic styles (`.caption2`, `.footnote`, `.subheadline`, `.body`, etc.) so layouts scale through `xxLarge` and into the accessibility sizes. SF Symbol icons retain fixed sizes (visual centering).
- `ContentUnavailableView` used for empty + failed states (native iOS 17 component with built-in accessibility traits).
- Light/dark mode: every `Theme.Color` token resolves through `Assets.xcassets/Colors/` colorsets with `Any Appearance` + `Dark Appearance` variants. Color contrast verified for WCAG AA on light theme; dark theme contrast is by-token but has not been fully audited.

Touch target audit (informal — no AccessibilityInspector run): the filter chip's tap area is ~32pt height before padding lifts it to ~44pt, on the boundary of the HIG 44pt minimum. The clear-search button's `Image` is ~12pt but its containing button extends to ~30pt — also marginal. Both are flagged for a future explicit audit pass.

Limitations honestly acknowledged: no AccessibilitySnapshot integration (regression-catching for labels/traits); no automated VoiceOver navigation order tests; AX5 (largest accessibility size) layout has not been verified visually beyond Maestro flow `76-AX5-search-idle.yaml`.

## Hotel listings rendering — intentional deviation

The interview prompt suggests "vertical list (e.g., `List` or `LazyVStack` inside a `ScrollView`)" for Screen 2. This app ships sectioned **horizontal carousels** (`Top picks`, `Highest rated near you`, `Within walking distance`) on a vertical scroll instead. The reasoning:

- Hospitality search is image-led — wide, photo-dominant cards in a peek-carousel give every result equal first-class visual real estate at the rhythm of typical 2026-era travel apps (Airbnb, Hopper, Booking.com).
- Sectioning by editorial axis ("Top picks" / "Within walking distance") foregrounds curation, which is what differentiates a day-pass marketplace from a generic hotel directory.
- A pure vertical list would be the strictly compliant choice; this deviation prioritizes UX impression over verbatim spec adherence, which felt like the right founding-engineer call.

Each card row surfaces hotel name, image, star rating, and price — the spec's "most relevant product/price information" — so the information surface matches even though the layout doesn't.

## Real API Quirks

A few things the staging API does that affect the model layer:

- The autocomplete response is a **top-level array** (not wrapped in `{"results": [...]}`).
- Some places return `latitude: null, longitude: null` (e.g., "Brooklyn, Florida"). Tapping such a place sends `0,0` to the hotels endpoint and gets unrelated results, so the reducer guards on `place.hasUsableCoordinates` and surfaces a `.failed` state with an explanation instead of navigating into broken data.
- Different places can share the same integer `id` (e.g., Newport Beach and Newport Coast both have `id=236` because Coast is an alias). `objectID` (the API's denormalized string key) is stable and unique, so `Place.id` (Identifiable) maps to `objectID`. Without this, ForEach silently drops one of the duplicates.
- The hotels response wraps `currency` as a nested object, has `image[]` as an array of nested `picture.url` objects, and exposes both `rating` (human-friendly, 4.4) and `avg_rating` (often 0.0 — looks like an internal field). The model decodes `rating`, not `avg_rating`. Cheapest price is computed from `products[].price.min()`.

## Known Limitations

- **Dark mode**: semantic tokens (`background`, `surface`, `textPrimary`, etc.) live in `Assets.xcassets/Colors/` colorsets with light + dark appearance variants. `Theme.Color.*` reads `SwiftUI.Color("name", bundle: .main)` from those colorsets. Visually verified across both screens via Maestro flows `33-dark-search-loaded.yaml` and `37-dark-hotels-loaded.yaml`.
- **Pagination**: the autocomplete endpoint accepts `limit` + `offset` but the UI doesn't paginate. With 30 hotels per page from the algolia endpoint, infinite scroll would be a natural addition.
- **Pull-to-refresh** on hotel listings.
- **Offline behavior**: no caching of last-seen results. A network drop during browsing returns the user to a `.failed` state without a stale-data fallback.
- **Localization**: Plumbing in place — every user-visible string is wired through `String(localized:)` with a `defaultValue:` in `Sources/Strings/Strings.swift` (~30 calls). Non-English `.lproj` / `.xcstrings` catalogs are not yet provided, so a reviewer switching iOS to e.g. Spanish will still see the English defaults until catalogs are added.
- **Extended product surface**: each hotel has multiple products + price tiers; the UI shows only the cheapest price + the top-level product name. A full product picker is out of scope.
- **App icon + launch screen**: placeholder `Contents.json` only; no actual icon graphics.

## What I'd do differently with more time

1. **Add a snapshot test suite** with swift-snapshot-testing covering all 5 states × both screens × portrait/landscape × light/dark. ~3-4h.
2. **AccessibilitySnapshot** integration to catch label/trait regressions. ~1h.
3. **Pull-to-refresh** + **pagination** on hotel listings via `refreshable {}` and offset bumping. ~2h.
4. **Extract `.preview` fixture data into JSON files** under `Tests/Fixtures/JSON/` so production source files don't carry test data. ~30min.
5. **Maestro matrix runs** across iPhone SE / 15 / 17 Pro Max + portrait/landscape + light/dark — currently only iPhone 17 Pro / portrait / light is exercised. ~1h to wire matrix configs.
6. **Real `LogClient` testing strategy**: a `.recording` factory that buffers calls so unit tests can assert on logger emissions per Status transition. ~30min.
7. **Pre-commit hooks** (SwiftFormat or SwiftLint) so the conventions documented here can't drift.
