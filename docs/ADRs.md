# Architecture Decision Records

Significant design choices made during this take-home, in roughly chronological order. Each record includes the context, the decision, and (where applicable) the trade-off accepted.

---

## ADR-001 — Hand-rolled MVI, not TCA

**Context.** Two-screen take-home. State management options: MVVM (`@ObservableObject` or `@Observable`), MVI with hand-rolled reducer + `@Observable`, or The Composable Architecture (`swift-composable-architecture`).

**Decision.** Hand-rolled MVI with `@Observable @MainActor` view models. Each feature owns `State` struct + `Intent` enum + `ViewModel` exposing `private(set) var state` and `func send(_ intent:)`.

**Rationale.** MVI captures the unidirectional-flow + explicit-Intent benefits TCA offers without the framework dependency, learning curve, or boilerplate. For 2 screens the marginal benefit of TCA's Effect/Reducer/Store machinery doesn't justify its surface area in a reviewer's first read. `@Observable` from iOS 17 makes the macro overhead small.

**Trade-off accepted.** Effects are not first-class — Tasks are spawned inline inside reducer arms. Testing the reducer's effect output requires tolerating real `Task.sleep` delays in tests (visible in `SpecComplianceTests` debounce-timing tests). Switching to TCA would yield "intent X produced effect Y" assertions without any async runtime cost — but that's a refactor for the next 5 screens, not these 2.

---

## ADR-002 — Lift deployment target to iOS 17 (spec floor is 16)

**Context.** Interview spec: "Minimum deployment target should be iOS 16.0 or newer."

**Decision.** iOS 17 deployment target.

**Rationale.** iOS-17-only APIs that materially simplify this codebase: `@Observable`, `ContentUnavailableView`, value-based `NavigationStack(path:)` with stable bindings, `ContinuousClock` (lets the debounce constant be injected for tests), `.contentTransition(.numericText())`. Each has an iOS 16 fallback, but the fallbacks individually add 30-60 LOC of `#available(iOS 17.0, *)` branching. Lifting to 17 trades ~10-15% of the install base for a meaningfully simpler codebase at this scale.

**Trade-off accepted.** Cannot run on iOS 16 devices. Lower install-base ceiling. Documented in `README.md > Technical Choices`.

---

## ADR-003 — Function-style clients, not protocols

**Context.** Each network seam (Search, Hotels) needs to be swappable for tests. Options: protocol + class-based mocks, function-style `struct` of `@Sendable` closures, or DI container (Factory, Swinject).

**Decision.** Function-style clients. Each client is a `Sendable struct` whose fields are `@Sendable async throws` closures. Variants surface as static factories (`.live`, `.preview`, `.failing`, `.failingThenRecovers`).

**Rationale.** The Point-Free / TCA pattern. One-line test swap (`SearchClient { _ in [] }`) without conformance ceremony. Combines well with Swift Concurrency's `Sendable` constraint. At 3 dependencies, a DI container would be over-engineering. See `ARCHITECTURE.md > Composition root` for the "why not protocols" reasoning in detail.

**Trade-off accepted.** No compile-time discoverability of "which types implement this interface?" — you have to know the client is a struct of closures. For this scale it's a non-issue.

---

## ADR-004 — Sweep I (parallax GeometryReader → background+PreferenceKey) reverted

**Context.** An earlier change replaced the parallax block's `GeometryReader { proxy in ... .frame(width: proxy.size.width) }` with `.frame(maxWidth: .infinity)` + a `background+PreferenceKey` scroll-offset reader, aiming to avoid SwiftUI's GeometryReader-induced layout cascade.

**Decision.** Reverted (`commit c8621a3 — Revert "Replace parallax GeometryReader with background+PreferenceKey"`).

**Rationale.** The replacement's claim that "math is identical" missed an important detail: combined with `.scaledToFill()` on the hero image, `.frame(maxWidth: .infinity)` lets the image's natural fill width (heroHeight × image_aspect = 360 × ~1.5 = 540pt) propagate up through the VStack → ScrollView and bias the entire scroll content's width. Visible symptom: every text element on the listings screen rendered at negative-x (clipped on the left edge of the screen).

**Trade-off accepted.** The GeometryReader's layout-cascade perf cost returns. We accept it because the alternative is a real correctness bug.

---

## ADR-005 — Dismiss-no-refetch guard in HotelListings VM

**Context.** Popping the detail screen back to listings on iOS 18 (where detail is a pushed view) re-fires `.onAppear` / `.task`, which would trigger another fetch and tear the loaded list back to `.loading` (skeleton flash + redundant network call).

**Decision.** Idempotency guard in `HotelListings.send(.appeared)`: if `state.status` is `.loaded` or `.loading`, return early. Only `.idle`, `.empty`, `.failed` trigger a fresh `startFetch()`.

**Rationale.** The lifecycle hook can't tell "first appearance" from "pop-back re-appearance." Status-gated guard handles both cases correctly: a real first-load (status = `.idle`) fetches; a pop-back (status = `.loaded`) is a no-op. `.retryTapped` stays unconditional so explicit user retry always re-fetches.

**Trade-off accepted.** If data goes stale during a long background, `.appeared` won't refresh it — that's what the scenePhase-based staleness policy (ADR-006) handles.

Pinned by `SpecComplianceTests.test_hotelListings_appearedWhenAlreadyLoaded_doesNotRefetch`.

---

## ADR-006 — scenePhase staleness policy with 5-minute threshold

**Context.** ADR-005's dismiss-no-refetch guard prevents skeleton flash on pop-back, but it also prevents legitimate refresh after a long background. User opens app at 9am, sees hotels, backgrounds for 8 hours, returns to find stale availability/pricing.

**Decision.** Track `fetchedAt: Date` in `Loaded`. On `scenePhase → .active`, dispatch `.sceneDidBecomeActive` which compares elapsed time vs `Networking.Constants.listingsStaleThreshold` (5 minutes). If exceeded, trigger a fresh fetch.

**Rationale.** 5 minutes balances:
- "User briefly switched to Messages and back" → no refetch (no UX cost)
- "User came back hours later" → refetch (real stale-data risk)

Threshold is centralized in `Constants.swift` so a future product decision (3 min? 10 min?) is a one-line change.

**Trade-off accepted.** A user who backgrounds for 4 min 50s won't get a refresh; one at 5 min 10s will. The cliff is somewhat arbitrary. A more sophisticated solution would use a smoothed "freshness signal" (last-modified header, server-side staleness hint) — out of scope for take-home.

Pinned by three tests in `SpecComplianceTests.swift`: under-threshold no-op, over-threshold refetch, status-gated no-op when not `.loaded`.

---

## ADR-007 — StaggerArrival uses value-bound animation, not PhaseAnimator

**Context.** Detail content (subtitle, rating, time slot, price) was originally animated in via `PhaseAnimator([0.0, 1.0], trigger: contentArrivalTrigger)` — content drops in from `phase 0` (offset 12pt, opacity 0) to `phase 1` (settled, opaque) on first appear.

**Symptom.** On iOS 18's `.navigationTransition(.zoom)` path, the destination view is re-instantiated post-morph. The @State `contentArrivalTrigger` is preserved as `true`, but PhaseAnimator's internal phase index resets to 0. Since the trigger value didn't change, PhaseAnimator didn't re-advance — content got stuck at phase 0 (opacity 0). Visible: content arrived briefly during morph, then faded out.

**Decision.** Replace PhaseAnimator with direct value-bound animation:

```swift
content
    .opacity(trigger ? 1.0 : 0.0)
    .offset(y: trigger ? 0 : 12)
    .animation(Theme.Animation.contentArrival.delay(staggerDelay), value: trigger)
```

**Rationale.** Direct binding has no internal phase state — opacity/offset are pure functions of `trigger`. Re-instantiation can't desync them.

**Trade-off accepted.** Loses the declarative phase-list expressiveness that would matter at more than 2 phases. For the current 2-phase use case (hidden → visible), value-bound is semantically equivalent and more robust.

Pinned in commit `25987de`.

---

## ADR-008 — AppDependencies bundling

**Context.** Pre-refactor, `SearchClient` was wired in `ResortPassApp.init`, but `HotelsClient` was wired (with its own DEBUG launch-argument logic) in `RootNavigationView.body`. Two places to read to see the full dependency graph; duplicated UserDefaults parsing.

**Decision.** Introduce `AppDependencies` (`Sources/App/AppDependencies.swift`) — a `Sendable struct` bundling `search`, `hotels`, and `logger` with `.live()` and `.preview` factories. Built once in `ResortPassApp.init`. Threaded via `@Environment(\.dependencies)`. (An earlier draft also bundled `http`, but no consumer reads it directly — each client builds its own `HTTPClient.live()` internally — so it was dropped to keep the surface minimal.)

**Rationale.** Single composition root. Read one file to see every dependency. View-model constructor injection still takes the specific client (separation of concerns) — the bundle is for views that need ad-hoc access without prop-drilling.

**Trade-off accepted.** Adds a layer of indirection (env value → struct field → client). For 3 clients the value clearly exceeds the cost. At 1-2 clients the indirection would be over-engineering.

---

## ADR-009 — Sectioned horizontal carousels for Hotel Listings (spec asks for vertical list)

**Context.** Interview spec for Screen 2: "Render the results in a vertical list (e.g., `List` or `LazyVStack` inside a `ScrollView`)."

**Decision.** Sectioned horizontal carousels in a vertical scroll instead. Four sections, built by a pure section pipeline on the loaded state:

- `Top picks` (subtitle: *Highest rated near you*) — top 5 by rating
- `Within walking distance` — hotels within 1.5 mi
- `Best value` (subtitle: *Lowest day passes today*) — cheapest 5 by price
- `All hotels` — fallback for everything not surfaced in the curated sections

**Rationale.** Hospitality search is image-led — wide photo-dominant cards in a peek-carousel give every result equal first-class visual real estate, matching the rhythm of 2026-era travel apps (Airbnb, Hopper, Booking.com). Sectioning by editorial axis surfaces curation, differentiating a day-pass marketplace from a generic directory.

**Trade-off accepted.** Strict spec compliance forfeited. Documented in `README.md > Hotel listings rendering — intentional deviation` so a reviewer sees the deliberate choice. Each row still surfaces the spec's required "hotel name, image, rating, and most relevant product/price information" (the `product_name` was promoted to a tertiary subtitle on the card per the spec — see commit `51405d9`).
