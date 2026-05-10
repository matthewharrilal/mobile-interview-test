# Architecture

Single-target SwiftUI app, hand-rolled MVI, Swift Concurrency. This document records the conventions the folder structure encodes — the compiler doesn't enforce these (no SPM split today), so the discipline is conventional and grep-gated.

## Layers

```
App           ─┐
Features      ─┤  presentation (SwiftUI views + view models)
              ─┘
DesignSystem  ─┐
Routing       ─┤  cross-cutting helpers
Strings       ─┤
Logging       ─┘

Models        ─┐  domain (Codable types)
              ─┘

Networking    ─┐  data (HTTP clients, decoders, error mapping)
ImageCaching  ─┤
              ─┘
```

**Dependency direction is unidirectional.** Presentation depends on Models + Networking. Networking and Models never reach upward. A feature must not import another feature's internals.

## Conventions

- **One target, no SPM split.** Boundary discipline is held by convention, not the compiler. At scale, splitting Networking + DesignSystem + Models into SPM modules is the obvious next step — see `docs/ADRs.md` for why we deferred.
- **`Networking/*` is a leaf.** It depends on Foundation only. It never imports from `Features/`, `Models/`, or `DesignSystem/`.
- **Features may not cross-import.** `Search` cannot import `HotelListings.swift`. `HotelDetail` is the one exception — it's instantiated as a destination view from `HotelListings`, but the instantiation site is `RootNavigationView` (the composition root), not a peer feature.
- **`DesignSystem/Components/*`** currently consumes concrete `Hotel`/`Currency` domain types. A pure design system would take view-data structs — that's the cost of the deferred SPM split.
- **Routing carries domain payloads** (`AppDestination.hotelListings(place:)`). At scale you'd want identifier-only payloads with a registry, but for 2 destinations the explicit-payload shape is more readable.

## Composition root

A single `AppDependencies` value (`Sources/App/AppDependencies.swift`) bundles every Sendable client the app uses (`search`, `hotels`, `http`, `logger`). Built once in `ResortPassApp.init` via `AppDependencies.live()`, with DEBUG-only launch-argument overrides for Maestro UI tests. Threaded via `@Environment(\.dependencies)` so any view can reach a dependency without prop-drilling; view models still take their specific client via constructor injection at the boundary (separation of concerns).

This replaces the earlier split where `SearchClient` was wired in `ResortPassApp.init` but `HotelsClient` was wired in `RootNavigationView.body`. There's now one place to read to see the whole graph.

**Why function-style clients (not protocols)?** Each "client" is a `Sendable struct` whose fields are `@Sendable async throws` closures (e.g. `struct SearchClient { var search: @Sendable (String) async throws -> [Place] }`). Test swap = one-line closure replacement. Protocols would force a separate `class MockSearchService: SearchService` per test variant — overhead with no expressiveness gain over Swift Concurrency closures.

## State management

MVI with `@Observable`. Each feature owns a **State** struct + **Intent** enum + **ViewModel** (`@Observable @MainActor final class`):

```
View ── send(.intent) ──▶ reducer (sync) ──▶ state mutation
                                         └─▶ Task { client.fetch() } ──▶ state mutation on completion
```

- `state` is `private(set)`. The only mutation path is `send(_:)`.
- The reducer is **synchronous and pure** with respect to its inputs.
- Async work is spawned inside `Task` from the reducer's intent arms.
- Cancellation: every `startFetch` cancels the previous `Task` before spawning a new one, AND uses `try Task.checkCancellation()` between awaitable steps.
- Stale-response guard: a slow response that lands after the user has typed a different query is gated by `guard query == self.state.query.trimmingCharacters(in: .whitespaces)` (`Search.swift:143`). Pinned by `SpecComplianceTests.test_staleResponseGuard_olderQueryResponseDoesNotClobberNewerState`.

Path mutation also routes through the reducer (`SearchIntent.pathChanged(_:)`), so swipe-back gestures and programmatic pushes both flow through `send(_:)`. The unidirectional invariant holds even for system-driven navigation.

## Concurrency

- **`async/await` is the default.** Zero `DispatchQueue` references in `Sources/` (verified by grep).
- **`@MainActor` annotation, not dispatch.** View models are `@MainActor`. Network I/O happens off-main inside `URLSession.data(for:)`; results are awaited back on main.
- **Task cancellation cascades.** Outer `Task.cancel()` → `URLSession.dataTask.cancel()` → `URLError.cancelled` surfaces and is caught silently in the VM (`Search.swift:149-152`, `HotelListings.swift:297-300`).
- **`.task { ... }` over `.onAppear`.** `HotelListingsView` uses `.task { viewModel.send(.appeared) }` so the in-flight fetch is auto-cancelled when the view leaves the hierarchy.
- **scenePhase staleness policy.** When the app returns from background, `HotelListings.sceneDidBecomeActive` checks elapsed time vs `Networking.Constants.listingsStaleThreshold` (5 min) and triggers a refresh if stale. Brief backgrounds (< threshold) preserve loaded state.

## Decoding resilience

- **Wire types separated from domain types.** `HotelsWireResponse` (private nested wire shape) → `HotelsSearchResponse` (domain), with explicit fallbacks at the seam (`?? "USD"` for currency code, etc.).
- **Lossy array decoding.** `Sources/Networking/FailableDecodable.swift` provides `FailableDecodable<T>` + `JSONDecoder.decodeLossy(_:from:)`. One malformed `Place` or `Hotel` row drops itself instead of nuking the whole array.
- **`try?` on optional fields.** `Hotel.init(from:)` uses `try? decodeIfPresent` for `hotelStar`, `cityName`, `stateCode`, `vibes`, `products` — partial schema drift on those fields silently nilles them rather than failing the entire row. Documented trade-off: degrades gracefully vs surfacing `.failed(.decodeError)`. Pinned by `PlaceTests.test_decode_hotelWithHotelStarAsString_silentlyNilled` and conjugates.
- **Required fields throw.** `Hotel.id` and `Hotel.name` are required. A type-mismatched id raises `DecodingError`. Combined with the lossy-array wrapper, this means: one bad hotel drops, but a bad shape on a required field surfaces visibly.

## Navigation

`NavigationStack(path:)` with a value-based `AppDestination` enum. Path is bound via `Binding(get:set:)` whose setter dispatches `.pathChanged([AppDestination])` so user-driven swipe-back and programmatic pushes both flow through the reducer.

**OS-version split.** `AppDestination.hotelDetail` is only produced on iOS 18+ (where `.matchedTransitionSource` + `.navigationTransition(.zoom)` are available). On iOS 17 the detail lives in `HotelListingsState.PresentationLayer.detailExpanded` — a ZStack overlay driven by `matchedGeometryEffect`. Same destination, two implementations, gated on `useZoomTransitionPath`. The iOS 17 path is the fallback; iOS 18+ is the primary.

## Testing strategy

- **Unit tests** at `Tests/` — 83 tests across 6 files:
  - `SearchViewModelTests.swift` (11) — reducer behavior
  - `HotelListingsViewModelTests.swift` (5) — reducer behavior
  - `SpecComplianceTests.swift` (21) — explicit interview-spec pinning (500ms debounce timing, cancellation race, dismiss-no-refetch, scenePhase staleness, presentation transitions)
  - `HTTPClientTests.swift` (7) — URLProtocol-stubbed transport: status mapping, cancellation cascade, non-HTTP response handling
  - `NetworkingLayerTests.swift` (18) — Endpoints URL verbatim vs interview spec + ErrorKind mapping for every URLError case
  - `PlaceTests.swift` (15) — decoding against real API fixtures + adversarial inputs (id-as-string, vibes-null, products-as-object, lossy-array recovery)
  - `HotelTests.swift` (6) — Hotel decoder coverage
- **Maestro flows** at `.maestro/` (~80 flows) — end-to-end interaction tests including non-Latin search input, debounce/cancellation, null-coord guard, dark mode, AX5 Dynamic Type, landscape, RTL, offline simulation.
- **Snapshot tests** are not implemented — flagged in "What I'd do differently with more time" in the README. The `.preview` clients give deterministic fixtures that would let a snapshot suite plug in cheaply.
