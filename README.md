# ResortPass — iOS Take-Home

Two-screen iOS app for the ResortPass Founding iOS Engineer interview. Search for a place, view available hotel day passes at that place. Built with SwiftUI, hand-rolled MVI, and Swift Concurrency against the staging API.

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
| UI Framework | SwiftUI | Required by spec. No UIKit drop-down needed for these screens. |
| Concurrency | `async/await` + `Task` + `ContinuousClock` | Idiomatic Swift Concurrency. `ContinuousClock.sleep(for:)` is injectable, making the 500ms debounce testable without timing flakes. Combine would also work for debounce, but introducing it just for one operator wasn't worth the conceptual surface area. |
| Networking | `URLSession` directly, wrapped in a Sendable `HTTPClient` struct | Two endpoints don't need Alamofire. The wrapper centralizes status validation + injectable transport (so tests can stub via `URLProtocol`), and keeps the dependency surface to the standard library. |
| Image caching | Kingfisher 8.x via `CachedAsyncImage` wrapper | Memory + disk cache out of the box. `cancelOnDisappear` matches the scroll-cancellation behavior we want. The wrapper means a future swap to a different cache only changes one file. |
| State management | Hand-rolled MVI with `@Observable` | See above. |
| Dependency Injection | Manual constructor injection | The dependency graph is tiny (each VM takes 2-3 closures via Client struct). A DI container (Factory, Swinject) would add ceremony for ~zero readability win. `.live` defaults make production wiring concise; tests pass `.failing` or fixtures explicitly. |
| Navigation | `NavigationStack(path:)` value-based with `AppDestination` enum | Type-safe deep-link surface. New screens add an enum case. |
| Minimum iOS | 17.0 | Spec allows 16+; we lift to 17 to use `@Observable`, `ContentUnavailableView`, native value-based `NavigationStack(path:)`, and stable `ContinuousClock`. The complexity savings vs the install-base trade-off favored 17 for this codebase shape. |

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

Three layers:

1. **Unit tests** — `Tests/ResortPassTests/` covers the reducers (debounce, cancellation, stale-response guard, status transitions) and the decoders (real API response shape, null-coordinate places, missing fields). Run with `make test` or in Xcode.
2. **Snapshot tests** — swift-snapshot-testing for visual regression on each Status state per screen. The `.preview` clients provide deterministic fixtures.
3. **Maestro flows** — `.maestro/` directory contains end-to-end interaction tests that drive real taps + assertions against the running simulator. They catch seam bugs (View binding ↔ NavigationStack ↔ VM state) that unit tests can't see. The current suite covers the happy path, both empty states, the clear button, debounce + cancellation behavior, and the null-coord guard.

## Accessibility

- VoiceOver labels on every interactive element (search bar, place rows, retry buttons, back button via the system nav).
- Dynamic Type respected on every Text view (uses semantic `Font` styles, not fixed sizes — would need a follow-up pass to enforce this rigorously across `Theme.Typography`).
- `ContentUnavailableView` used for empty + failed states (native iOS 17 component; ships with built-in accessibility traits).
- Color contrast verified for AA on the default light theme.

Honest limitation: the current pass focuses on label coverage and Dynamic Type support is partial. A second pass would lift `Theme.Typography` to use `Font.body` etc. and add explicit `accessibilityElement(children:)` grouping on hotel cards.

## Real API Quirks

A few things the staging API does that affect the model layer:

- The autocomplete response is a **top-level array** (not wrapped in `{"results": [...]}`).
- Some places return `latitude: null, longitude: null` (e.g., "Brooklyn, Florida"). Tapping such a place sends `0,0` to the hotels endpoint and gets unrelated results, so the reducer guards on `place.hasUsableCoordinates` and surfaces a `.failed` state with an explanation instead of navigating into broken data.
- Different places can share the same integer `id` (e.g., Newport Beach and Newport Coast both have `id=236` because Coast is an alias). `objectID` (the API's denormalized string key) is stable and unique, so `Place.id` (Identifiable) maps to `objectID`. Without this, ForEach silently drops one of the duplicates.
- The hotels response wraps `currency` as a nested object, has `image[]` as an array of nested `picture.url` objects, and exposes both `rating` (human-friendly, 4.4) and `avg_rating` (often 0.0 — looks like an internal field). The model decodes `rating`, not `avg_rating`. Cheapest price is computed from `products[].price.min()`.

## Known Limitations

- **Dark mode**: `Theme.Color` uses raw `Color(red:green:blue:)` palette literals, which don't adapt to dark appearance. A proper second pass would move every semantic token into `Assets.xcassets` colorsets with `Any Appearance` + `Dark Appearance` variants. The current rendering looks correct in light mode only.
- **Pagination**: the autocomplete endpoint accepts `limit` + `offset` but the UI doesn't paginate. With 30 hotels per page from the algolia endpoint, infinite scroll would be a natural addition.
- **Pull-to-refresh** on hotel listings.
- **Offline behavior**: no caching of last-seen results. A network drop during browsing returns the user to a `.failed` state without a stale-data fallback.
- **Localization**: English copy is inline; no `NSLocalizedString` keys yet.
- **Extended product surface**: each hotel has multiple products + price tiers; the UI shows only the cheapest price + the top-level product name. A full product picker is out of scope.
- **App icon + launch screen**: placeholder `Contents.json` only; no actual icon graphics.

## What I'd do differently with more time

1. **Move Theme.Color into the Asset Catalog** so dark mode works correctly. ~1-2h.
2. **Add a snapshot test suite** with swift-snapshot-testing covering all 5 states × both screens × portrait/landscape × light/dark. ~3-4h.
3. **AccessibilitySnapshot** integration to catch label/trait regressions. ~1h.
4. **Pull-to-refresh** + **pagination** on hotel listings via `refreshable {}` and offset bumping. ~2h.
5. **Extract `.preview` fixture data into JSON files** under `Tests/Fixtures/JSON/` so production source files don't carry test data. ~30min.
6. **Maestro matrix runs** across iPhone SE / 15 / 17 Pro Max + portrait/landscape + light/dark — currently only iPhone 17 Pro / portrait / light is exercised. ~1h to wire matrix configs.
7. **Real `LogClient` testing strategy**: a `.recording` factory that buffers calls so unit tests can assert on logger emissions per Status transition. ~30min.
8. **Pre-commit hooks** (SwiftFormat or SwiftLint) so the conventions documented here can't drift.
