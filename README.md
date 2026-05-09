# ResortPass — iOS Take-Home

Two-screen iOS app: search for a place, view available hotel day passes at that place. Built with SwiftUI, hand-rolled MVI, and Swift Concurrency.

## Setup

```
make setup   # generates ResortPass.xcodeproj and opens it in Xcode
make build   # builds for iPhone 15 Simulator
make test    # runs the test suite
make clean   # clears DerivedData
```

Requires Xcode 15+ (iOS 17 minimum) and XcodeGen (`brew install xcodegen`).

## Folder Tree

```
ResortPass/
├── project.yml                    XcodeGen project definition
├── Makefile                       setup / build / test / clean targets
├── README.md                      this file
├── Sources/
│   ├── App/                       entry point, root composition (App.swift, RootContainer)
│   ├── Models/                    cross-feature domain types (Place, Hotel, Currency)
│   ├── Networking/                IO boundary (HTTPClient, Endpoints, SearchClient, HotelsClient)
│   ├── DesignSystem/
│   │   ├── Tokens/                Palette → Theme tier (Color, Spacing, CornerRadius, Typography)
│   │   └── Components/            reusable views (CachedAsyncImage, EmptyStateView, ErrorStateView)
│   ├── Routing/                   AppDestination enum + NavigationStack root
│   ├── ImageCaching/              Kingfisher integration shim
│   ├── Common/                    cross-feature utilities (LossyArray, etc.)
│   ├── Strings/                   user-facing copy + accessibility labels
│   ├── Logging/                   LogClient (function-style)
│   ├── Resources/
│   │   └── Assets.xcassets/       AccentColor, semantic Colors/
│   └── Features/
│       ├── Search/                SearchViewModel + SearchView + tests
│       └── HotelListings/         HotelListingsViewModel + HotelListingsView + tests
└── Tests/                         per-feature unit + snapshot tests
```

## Architecture

Hand-rolled MVI with `@Observable`. Each feature owns:
- A `State` struct with a nested `Status` enum (.idle / .loading / .loaded / .empty / .failed).
- An `Intent` enum naming every action that mutates state.
- A `ViewModel` (@Observable @MainActor final class) that exposes `private(set)` state and a synchronous `send(_ intent:)` reducer that spawns Tasks for async work.
- A `Client` (function-style struct of `@Sendable async throws` closures) injected via constructor with `.live`, `.failing`, and `.preview` extensions.

Navigation uses `NavigationStack` with value-based `.navigationDestination(for: AppDestination.self)`.

### Per-feature client shape

One client per feature (`SearchClient`, `HotelsClient`) — never a shared "ApiClient" god-object. Each client is a `Sendable struct` of `@Sendable async throws` closures with `.live`, `.failing`, and `.preview` extensions. Constructor-injected; production wiring happens once in `ResortPassApp.swift`.

### Module dependency rules

The import direction is one-way: `Features → DesignSystem, Models, Networking, Routing, Common, Logging`. The reverse is forbidden and grep-gated. `Features/*` modules MAY NOT import each other; cross-feature work goes through value types (`AppDestination`, `Place`).

| Module          | Imports (allowed)                                  | Exports                              | Inbound dependents          |
|-----------------|----------------------------------------------------|--------------------------------------|-----------------------------|
| Models          | Foundation                                         | `Place`, `Hotel`, `Currency`         | every feature, networking   |
| Networking      | Foundation, Models                                 | `SearchClient`, `HotelsClient`, `Endpoints`, `Networking.Constants` | features                    |
| DesignSystem    | SwiftUI                                            | `Theme`, `Spacing`, `CornerRadius`, `Typography`, components | views                       |
| Routing         | Models                                             | `AppDestination`                     | App, every feature          |
| ImageCaching    | Kingfisher, SwiftUI                                | `CachedAsyncImage`                   | components, views           |
| Common          | Foundation                                         | `LossyArray`, utility helpers        | networking, models          |
| Strings         | Foundation                                         | localized keys                       | views                       |
| Logging         | Foundation, OSLog                                  | `LogClient`                          | features, networking        |
| Features/Search | DesignSystem, Models, Networking, Routing, Strings, Logging | `SearchView`, `SearchViewModel` | App, ResortPassTests        |
| Features/HotelListings | same as Search                              | `HotelListingsView`, `HotelListingsViewModel` | App, ResortPassTests |

### Constants and `static let`

Named numeric and string constants live in dedicated namespaces (`Networking.Constants`, `Theme.Spacing`, etc.). Inline literals (`50`, `0.5`, `"https://..."`) are forbidden in `Sources/` and grep-gated. `static let` is acceptable for immutable, IO-free values (defaults, ratios, colors); never for stateful caches.

### File header convention

Every Swift file in `Sources/` opens with a 3-line header: filename, one-line purpose, plus a single contextual line (architecture role or notable constraint). Applied to every `App/`, `Routing/`, `Models/`, `Networking/`, `DesignSystem/`, `Features/*` file. Grep-gated.

### Dependency choices

- **Kingfisher 8.x** for image caching. Memory + disk cache out of the box, `cancelOnDisappear` mirrors the behaviour we want for scroll-cancellation, mature SwiftUI bridge via `KFImage`. Wrapped behind `CachedAsyncImage` so the integration is replaceable.
- **swift-snapshot-testing** + **AccessibilitySnapshot** for visual + accessibility regression. Lands when the testing layer ships.

### AppDestination growth

`AppDestination` is the single value-based enum used by `NavigationStack(path:)`. New push-able screens add a case here. Keeping all destinations in one type keeps deep-link routing trivial and the navigation stack value-based throughout.

### Seven growth vectors

Future expansion vectors the architecture is positioned for:
1. New screens — add an `AppDestination` case + Feature folder.
2. New API clients — function-style struct + `.live`/`.failing`/`.preview` extensions.
3. New design tokens — Palette tier raw value → Theme tier semantic alias.
4. New environments — extend `APIEnvironment` enum (staging / production / mock).
5. New test types — Tests/ folder per type (snapshot, unit, accessibility).
6. New caches — wrap behind a Client struct, inject via constructor.
7. New cross-feature shared types — promote to `Models/` or `Common/`.

### Naming conventions

**Intents** (per R6): `{noun}Tapped` for UI taps, `{noun}Changed` for value mutations, `{noun}{Verbed}` (past tense) for completion intents. Examples: `clearTapped`, `queryChanged(String)`, `placeSelected(Place)`, `searchCompleted(places: [Place])`.

**Type suffixes — forbidden**: `Manager`, `Service`, `Helper`, `Util`. These leak nothing about purpose. Use the noun for what the type actually is (`SearchClient`, not `SearchService`; `LossyArray`, not `ArrayHelper`).

**Response types** (R10): plural form for collection-bearing responses (`HotelsSearchResponse` not `HotelSearchResponse`). The plurality of the wire response is part of the contract.

**Wire fields** (R7): wire-level identifiers like `queryID`, `objectID`, `indexName` are stripped at the decode boundary — they don't propagate into domain types. The `Hotel` model has `id: String` (mapped from `objectID`); the wire `queryID` is dropped during decode.

**Cross-cutting placement** (R11, R12): `AppDestination` lives in `Routing/` (not `App/` or `Features/`). `LossyArray<T>` lives in `Common/` (not in any feature folder).

### iOS 17 minimum

The interview spec allows iOS 16+. We target iOS 17 to use `@Observable`, `ContentUnavailableView`, value-based `NavigationStack` natively, and `ContinuousClock` injection without backports. This is a deliberate trade-off: the architecture stays simpler, the code reads idiomatically, and the take-home doesn't drag in fallback shims for one minor-version difference. The current iOS 17 install base is high enough that this rarely costs real coverage. The exception list:
- `@Observable` — iOS 17+ only; pre-17 alternative would be `ObservableObject`.
- `NavigationStack(path:)` — available in iOS 16, but the value-based `.navigationDestination(for:)` shape we use is cleaner with iOS 17.
- `ContinuousClock` — available since iOS 16, but the API stabilised in 17.

### File header convention applied

Every file in `App/`, `Features/`, `Networking/`, `Models/`, `DesignSystem/`, `Routing/`, `ImageCaching/`, `Common/`, `Strings/`, `Logging/` opens with the canonical 3-line header (filename, purpose, contextual line).

### Canonical MARK list

Per file type, the standard `// MARK: - X` headers are:
- **Feature files** (`Search.swift`, `HotelListings.swift`): `State`, `Intent`, `ViewModel`
- **View files** (`SearchView.swift`, `HotelListingsView.swift`): `Body`, `Subviews`, `Accessibility`
- **Client files**: `Live`, `Failing`, `Preview` (one per extension)
- **Token files**: by category (`Color`, `Spacing`, `Typography`, `CornerRadius`)
- **Test files**: `Setup`, `Tests`, `Helpers`
