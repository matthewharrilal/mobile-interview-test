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

More architectural detail will land in this README as the implementation completes.
