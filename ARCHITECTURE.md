# Architecture

Single-target SwiftUI app with hand-rolled MVI and Swift Concurrency. This document records the conventions the folder structure encodes — the compiler doesn't enforce them (no SPM split today), so the discipline is kept by convention and grep-gated where it matters.

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

Networking    ─┐  data (HTTP client + orchestration + decoders + error mapping)
ImageCaching  ─┤
              ─┘
```

**Dependencies flow one direction.** Presentation depends on Models + Networking. Networking and Models never reach upward. A feature must not import another feature's internals.

## Conventions

- **One target, no SPM split.** The boundaries are held by convention, not the compiler. Splitting Networking + DesignSystem + Models into SPM modules is the obvious next step at scale — see `docs/ADRs.md` for why it's deferred.
- **`Networking/*` is a leaf.** It depends only on Foundation. It never imports from `Features/`, `Models/`, or `DesignSystem/`.
- **Features may not cross-import.** `Search` cannot import `HotelListings.swift`. `HotelDetail` is the one exception — it's instantiated as a destination view from `HotelListings`, but the instantiation site is `RootNavigationView` (the composition root), not a peer feature.
- **`DesignSystem/Components/*`** currently consumes the concrete `Hotel` / `Currency` domain types directly. A pure design system would take view-data structs — that's the cost we accepted with the deferred SPM split.
- **Routing carries domain payloads** (`AppDestination.hotelListings(place:)`). At scale you'd want identifier-only payloads with a registry, but for two destinations the explicit-payload shape reads more clearly.

## Composition root

A single `AppDependencies` value (`Sources/App/AppDependencies.swift`) bundles every Sendable client the app uses — `search`, `hotels`, and `logger`. (`http` used to live here too but was dropped because no consumer reads it directly; each client builds its own `HTTPClient.live()` internally.) The bundle is built once in `ResortPassApp.init` via `AppDependencies.live()`, with DEBUG-only launch-argument overrides for Maestro UI tests. It's threaded via `@Environment(\.dependencies)` so any view can reach a dependency without prop-drilling; view models still take their specific client by constructor injection at the boundary (separation of concerns).

This replaces the earlier split where `SearchClient` was wired in `ResortPassApp.init` but `HotelsClient` was wired in `RootNavigationView.body`. There's now one place to read to see the whole graph.

**Why function-style clients (not protocols)?** Each "client" is a `Sendable struct` whose fields are `@Sendable async throws` closures (e.g. `struct SearchClient { var search: @Sendable (String) async throws -> [Place] }`). Test swap is one closure replacement. Protocols would force a separate `class MockSearchService: SearchService` per test variant — overhead with no expressiveness gain over Swift Concurrency closures.

## Networking layer

Two endpoints, one transport seam. A small `HTTPClient` wraps `URLSession` and centralizes status checks plus injectable transport (so tests can stub it via `URLProtocol`). On top of that sits a single orchestration helper, `HTTPClient.executeJSON<T>`, which owns the cross-cutting work each endpoint would otherwise duplicate:

- structured logging at start, end, and on failure
- `Task.checkCancellation()` after the network call and after decode
- decode-error wrapping into `NetworkingError.decode`
- translating cancellation that comes from the URL layer (`URLError(.cancelled)` → `CancellationError`)

As a result, each feature client reads as ~10 lines that describe *what* the request does — build URL, build body, dispatch — and not how the transport works.

The layer is typed end-to-end:

- Raw HTTP method strings, header names, and content types are small `enum` types with helper extensions on `URLRequest` (`request.setMethod(.post)`, `request.setContentType(.json)`).
- The POST body for the hotels endpoint is a typed `Encodable` struct (`AlgoliaHotelsRequest`), not `[String: Any]` + `JSONSerialization`.
- Log event names are a `LogEvent` enum so a typo can't silently break log indexing.
- The single `@unchecked Sendable` escape hatch from the previous design (a manual NSLock-protected `CallCounter`) was replaced by a Swift `actor`.

## State management

MVI with `@Observable`. Each feature owns a **State** struct + **Intent** enum + **ViewModel** (`@Observable @MainActor final class`):

```
View ── send(.intent) ──▶ reducer (sync) ──▶ state mutation
                                         └─▶ Task { client.fetch() } ──▶ state mutation on completion
```

- `state` is `private(set)`. The only mutation path is `send(_:)`.
- The reducer is **synchronous and pure** with respect to its inputs.
- Async work is spawned inside `Task` from the reducer's intent arms.
- Cancellation: every `startFetch` cancels the previous `Task` before spawning a new one, and the task body uses `try Task.checkCancellation()` between awaitable steps.
- Stale-response guard: a slow response that lands after the user has typed a different query is caught by `guard query == self.state.query.trimmingCharacters(in: .whitespaces)` (`Search.swift:133`). Pinned by `SpecComplianceTests.test_staleResponseGuard_olderQueryResponseDoesNotClobberNewerState`.

Path mutation also flows through the reducer (`SearchIntent.pathChanged(_:)`), so swipe-back gestures and programmatic pushes both go through `send(_:)`. The one-way data flow holds even for system-driven navigation.

## Concurrency

- **`async/await` is the default.** Zero `DispatchQueue` references in `Sources/` (verified by grep).
- **`@MainActor` annotation, not dispatch.** View models are `@MainActor`. Network I/O runs off-main inside `URLSession.data(for:)`; results are awaited back on main.
- **Task cancellation cascades.** Outer `Task.cancel()` → `URLSession.dataTask.cancel()` → `URLError(.cancelled)` surfaces, gets translated to `CancellationError` by the orchestration helper (and again at the VM catch arms via `Error.translatingCancellation()` for VM-side cancellations like rapid query changes), and is caught silently. See `Search.swift:149` and `HotelListings.swift:309`.
- **`.task { ... }` over `.onAppear`.** `HotelListingsView` uses `.task { viewModel.send(.appeared) }` so the in-flight fetch is auto-cancelled when the view leaves the hierarchy.
- **scenePhase staleness policy.** When the app returns from background, `HotelListings.sceneDidBecomeActive` compares elapsed time against `Networking.Constants.listingsStaleThreshold` (5 min) and triggers a refresh if stale. Brief backgrounds (under the threshold) keep the loaded state.

## Decoding resilience

- **Wire types separated from domain types.** `HotelsWireResponse` (a private wire shape) maps to `HotelsSearchResponse` (domain) via a `toDomain()` method on the wire type, with explicit fallbacks at the seam (`Currency.usd.code` for currency code, etc.).
- **Lossy array decoding by default.** `Sources/Networking/FailableDecodable.swift` provides `FailableDecodable<T>` plus two helpers: `JSONDecoder.decodeLossy(_:from:)` for top-level arrays and `KeyedDecodingContainer.decodeLossyArray(_:forKey:)` for arrays nested in a wire object. One malformed `Place` or `Hotel` row drops to nil instead of breaking the whole response.
- **`try?` on optional fields.** `Hotel.init(from:)` uses `try? decodeIfPresent` for `hotelStar`, `cityName`, `stateCode`, `vibes`, `products` — partial schema drift on those fields silently nils them rather than failing the entire row. Trade-off documented: degrades gracefully rather than surfacing `.failed(.decodeError)`. Pinned by `PlaceTests.test_decode_hotelWithHotelStarAsString_silentlyNilled` and conjugates.
- **Required fields throw.** `Hotel.id` and `Hotel.name` are required. A type-mismatched `id` raises `DecodingError`. Combined with the lossy-array wrapper, this means: one bad hotel drops, but a wrong shape on a required field still surfaces visibly.
- **Decoder split into helpers.** `Hotel.init(from:)` delegates to per-section private static helpers (`decodeImageURLs`, `decodePrimaryVibe`, `decodeCheapestPrice`) so the main init reads top-to-bottom in ~15 lines instead of 35.

## Navigation

`NavigationStack(path:)` with a value-based `AppDestination` enum. The path is bound via a `Binding(get:set:)` whose setter dispatches `.pathChanged([AppDestination])`, so user-driven swipe-back and programmatic pushes both flow through the reducer.

**OS-version split.** `AppDestination.hotelDetail` is only produced on iOS 18+ (where `.matchedTransitionSource` + `.navigationTransition(.zoom)` are available). On iOS 17 the detail lives in `HotelListingsState.PresentationLayer.detailExpanded` — a ZStack overlay driven by `matchedGeometryEffect`. Same destination, two implementations, gated on `useZoomTransitionPath`. The iOS 17 path is the fallback; iOS 18+ is the primary.

## Testing strategy

- **Unit tests** at `Tests/` — 120 tests across 12 files:
  - `SearchViewModelTests.swift` (11) — reducer behavior
  - `HotelListingsViewModelTests.swift` (5) — reducer behavior
  - `SpecComplianceTests.swift` (21) — explicit interview-spec pinning (500ms debounce timing, cancellation race, dismiss-no-refetch, scenePhase staleness, presentation transitions)
  - `HTTPClientTests.swift` (7) — URLProtocol-stubbed transport: status mapping, cancellation cascade, non-HTTP response handling
  - `NetworkingLayerTests.swift` (18) — `Endpoints` URL matched against the interview spec verbatim + `ErrorKind` mapping for every `URLError` case
  - `NetworkingConstantsTests.swift` (8) — direct pins for boundary constants (`successStatusRange`, `requestTimeout`, page sizes, debounce window, staleness threshold)
  - `SearchClientLiveTests.swift` (6) — direct coverage of the `.live` factory (URL build, lossy decode, error propagation, cancellation translation)
  - `HotelsClientLiveTests.swift` (9) — direct coverage of the `.live` factory (body shape, POST + Content-Type, wire-to-domain mapping, fallbacks, lossy decode)
  - `LogClientTests.swift` (3) — `.silent` factory discards, custom factory captures, `LogEvent` overload dispatch
  - `HotelListingsSectionsTests.swift` (11) — section pipeline (top-picks cap, walking distance boundary, best-value ordering, All fallback, filter integration)
  - `PlaceTests.swift` (15) — decoding against real API fixtures + adversarial inputs (id-as-string, vibes-null, products-as-object, lossy-array recovery)
  - `HotelTests.swift` (6) — Hotel decoder coverage + Codable round-trip
- **Maestro flows** at `.maestro/` (81 flows) — end-to-end interaction tests including non-Latin search input, debounce + cancellation, null-coord guard, dark mode, AX5 Dynamic Type, landscape, VoiceOver, Reduce Motion, German locale, and offline simulation.
- **Snapshot tests** are not implemented — listed in "With more time" in the README. The `.preview` clients give deterministic fixtures that would let a snapshot suite plug in cheaply.
