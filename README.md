# ResortPass — iOS

Two-screen iOS app for the ResortPass Founding iOS Engineer interview. Search a place, view hotel day passes there. Built with SwiftUI, hand-rolled MVI, and Swift Concurrency against the real staging API.

<sub>iOS&nbsp;17+ · Swift&nbsp;5.9 · 120&nbsp;unit&nbsp;tests · 81&nbsp;Maestro&nbsp;flows · 9&nbsp;ADRs · [CI&nbsp;wired](.github/workflows/ci.yml)</sub>

---

## What this submission ships above the brief

Two screens on the surface; the layers below are where the engineering lives. The highlights worth a reviewer's first 90 seconds:

- **Custom presentation logic.** The detail screen morphs in from the tapped card via iOS 18's matched-transition-source + zoom navigation transition, with a hand-written iOS 17 fallback (`matchedGeometryEffect` + ZStack overlay). Dismiss is a drag-throw with a `CADisplayLink`-driven rubber-band spring at the native 120 Hz on ProMotion, and the hero header parallaxes with a damped pull-down. None of this is in the spec — it's the part that makes the app feel like a product.

- **CI wired end-to-end.** [`.github/workflows/ci.yml`](.github/workflows/ci.yml) defines three GitHub Actions jobs: unit tests on every push, a Maestro smoke subset on every push, and the full 81-flow Maestro suite on a weekly schedule + manual dispatch. `xcresult` bundles and Maestro screenshots upload as artifacts on failure. [Live runs in the Actions tab](https://github.com/matthewharrilal/mobile-interview-test/actions).

- **Maestro as automation, not just regression-catching.** The 81 flows in [`.maestro/`](.maestro/) work as four things at once: an **automation harness** that runs every user path on demand; a **visual auditor** for animation envelopes and state transitions (see the comprehensive-visual-audit, stretchy-hero-audit, and transitions-audit flows); a **failure-state tester** via launch-arg-injected client variants (`--ui-test-fail-search`, `--ui-test-empty-hotels`, etc.) so every error UI is reachable without disrupting the staging API; and a **bug-finder** (the F12-05 landscape-keyboard issue, the iOS 26 / Maestro 2.5.1 incompatibility, and the null-coordinate dead-end were all caught by flows running unattended).

- **Design system as a dedicated module.** [`Sources/DesignSystem/Tokens/Theme.swift`](Sources/DesignSystem/Tokens/Theme.swift) is a two-tier (palette → theme) namespace covering Color, Spacing, CornerRadius, Animation, Icon, and Typography. Semantic colors resolve through Asset Catalog colorsets with light + dark appearance variants. Dynamic Type respected through `xxLarge` and into the accessibility sizes via semantic font styles. Custom Playfair Display fonts ship in the repo for editorial body type. Reusable components live in [`Sources/DesignSystem/Components/`](Sources/DesignSystem/Components/).

- **Accessibility verified end-to-end.** VoiceOver labels on every interactive element. Hotel cards combine via `.accessibilityElement(children: .combine)` for single-element rotor reading. Section headers carry the `.isHeader` trait. Empty and failed states use `ContentUnavailableView` (iOS 17 native, built-in traits). All of it pinned by dedicated Maestro flows for VoiceOver navigation, AX5 layout, Reduce Motion, Bold Text, and Increase Contrast — see §11.

- **Architecture that earned its decisions.** Function-style `Sendable` clients (one-line test swap, no protocol ceremony — see [ADR-003](docs/ADRs.md)) + a small `HTTPClient.executeJSON` orchestration helper that absorbs the cross-cutting transport work so each feature client stays around 10 lines. Composition root in [`AppDependencies`](Sources/App/AppDependencies.swift) with previews defaulting to fixture clients. [Nine ADRs](docs/ADRs.md) recorded for every decision worth defending.

- **Defensive engineering, honest about real-world failures.** Lossy array decode by default (one malformed row drops to nil rather than breaking the whole response). The null-coordinate guard shows a dedicated failure UI for places the staging API can't locate. Deliberate spec deviation (sectioned horizontal carousels vs the spec's vertical list, owned via [ADR-009](docs/ADRs.md)). iOS 26 + Maestro 2.5.1 incompatibility documented honestly so the next person knows why everything is pinned to iOS 18.

The same content in deeper detail follows below.

---

<sub>01 · SETUP</sub>

## Get it running

**Requirements.** Xcode 15 or later (needed for the iOS 17 SDK and the `@Observable` macro). An iOS Simulator running iOS 17 or later. Nothing else — the `.xcodeproj` is committed with its `project.yml`, the Kingfisher package version is pinned in `Package.resolved`, and the Playfair Display fonts ship in the repo.

```bash
git clone https://github.com/<your-fork>/mobile-interview-test.git
cd mobile-interview-test
open ResortPass.xcodeproj
```

In Xcode: pick **iPhone 16 Pro / iOS 18** as the simulator (the canonical target), then `Cmd+R` to build and run, `Cmd+U` to run the test suite. The first build takes about 30 seconds longer while Xcode resolves Kingfisher; later builds are cached.

Or use the `Makefile`, which pins the same simulator:

```bash
make build    # xcodebuild for iPhone 16 Pro / iOS 18
make test     # full unit suite (120 tests, ~20s)
make lint     # grep-gate on .animation(...) bindings
make clean    # nuke DerivedData
```

**Running Maestro flows locally** (optional — CI already runs all 81 flows, but you can run them yourself):

```bash
brew install openjdk@17                                                  # Maestro needs Java
curl -fsSL https://get.maestro.mobile.dev | bash                         # one-time install
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
maestro test .maestro/01-happy-path.yaml                                 # one flow
maestro test .maestro/                                                   # all 81
```

Maestro flows assume **iPhone 16 Pro / iOS 18** — they fail on iOS 26 because of a Maestro driver bug (see §9).

---

<sub>02 · DEMO</sub>

## Both screens, both themes

Real staging API. iPhone 16 Pro / iOS 18.

### Light theme

| Search idle | Search loaded | Hotel listings |
|---|---|---|
| ![idle light](snapshots/01-idle.png) | ![loaded light](snapshots/02-loaded.png) | ![hotels light](snapshots/03-hotels.png) |

### Dark theme

| Search idle | Search loaded | Hotel listings |
|---|---|---|
| ![idle dark](snapshots/01-idle-dark.png) | ![loaded dark](snapshots/02-loaded-dark.png) | ![hotels dark](snapshots/03-hotels-dark.png) |

### Signature motion

Two animations are easier to feel than describe: the card-to-detail morph and the sticky-header parallax. A captured walkthrough in dark mode:

https://github.com/user-attachments/assets/dark-mode-flow

<video src="docs/media/dark-mode-flow.mp4" controls width="380"></video>

The morph is the iOS 18 zoom transition with an iOS 17 fallback path. The parallax header stretches with a damped rubber-band feel, driven by `CADisplayLink` at 120 Hz on ProMotion. To see them locally at full fidelity, `maestro test .maestro/01-happy-path.yaml` exercises the morph and `15-swipe-down-dismiss-rubber-band.yaml` exercises the parallax.

---

<sub>03 · TL;DR</sub>

## What this is, in 15 seconds

> **The app.** Two screens: autocomplete search → place selection → hotel listings in sectioned horizontal carousels. The detail screen morphs in from the tapped card and dismisses with a drag-throw spring. Real staging API, light and dark, English with a Spanish stub.

> **What's notable.** Function-style `Sendable` clients (one-line test swap, no protocol ceremony). A small orchestration layer holds the transport's cross-cutting work in one place, so each feature client stays around 10 lines. The detail morph uses iOS 18's matched-transition-source with an iOS 17 fallback. 120 unit tests pin spec compliance and lossy decode behavior; 81 Maestro flows cover state cycles, animation audits, dark mode, AX5, German truncation, VoiceOver, and the failure UIs that launch arguments inject.

> **What didn't ship.** Snapshot testing, pull-to-refresh, pagination, full localization catalogs — all listed in §13–§14 with rough time estimates.

---

<sub>04 · ARCHITECTURE</sub>

## How it's built

Hand-rolled MVI with `@Observable`. Every feature owns four pieces:

- a **State** struct with a `Status` enum that covers every state (idle, loading, loaded, empty, failed, plus a feature-specific failure case when one's warranted),
- an **Intent** enum that names every mutation,
- a `@MainActor` **ViewModel** whose sync reducer is the only thing that mutates state,
- and a **Client** — a `Sendable struct` whose fields are `@Sendable async throws` closures.

Test swap is one line; no protocol-conformance work per test variant.

```
View → vm.send(.intent) → reducer (sync) → state mutation
                                       └→ Task { client.fetch() } → state mutation on completion
```

The reducer is synchronous and pure. The only side effect is spawning a `Task` for the network call, which checks cancellation at every async seam. A stale-response guard catches slow responses that land after the user has typed a new query. Cancellation from the system shows up as `URLError(.cancelled)`; a small helper rewrites it to `CancellationError` so view-model catch arms see one shape.

### Networking layer

Two endpoints, one transport seam. A small `HTTPClient` wraps `URLSession` and centralizes status checks plus injectable transport (so tests can stub it via `URLProtocol`). On top of that sits a single orchestration helper that owns the work each endpoint would otherwise duplicate: structured logging at start, end, and on failure; cancellation checks after the network call and after decode; decode-error wrapping; translating cancellation that comes from the URL layer. As a result, each feature client reads as ~10 lines that describe *what* the request does — build URL, build body, dispatch — and not how the transport works.

The layer is typed end-to-end. Raw HTTP method strings, header names, content types, and log event names are all small enums with helper extensions on `URLRequest`. The POST body for the hotels endpoint is a typed `Encodable` struct, not `[String: Any]` + `JSONSerialization`. Array decoding is lossy by default — one malformed `Place` or `Hotel` row drops to nil without breaking the rest of the response. Decode errors are wrapped in our own error type, so the view-model boundary sees one error type that already knows which errors are retryable.

### Navigation

`NavigationStack(path:)` with a value-based `AppDestination` enum. The path is bound to `state.path` through a binding whose setter dispatches a `.pathChanged` intent — pushes and pops both flow through the reducer, which keeps the one-way data flow intact. On iOS 18, the detail screen uses matched-transition-source + the system zoom navigation transition as the main morph. On iOS 17, it falls back to `matchedGeometryEffect` + a `ZStack` overlay. Both paths compile against the iOS 17 SDK through an `@available` gate.

> **Why MVI, not TCA or MVVM.** For two screens, TCA's framework dependency and learning surface didn't justify the cost. MVI captures the same essentials — one-way flow, an explicit intent enum, replayable transitions, a sync reducer, structured concurrency for side effects — without the third-party dependency. MVVM with `@Observable` would also work; I prefer the explicit intent enum because every state change shows up in one place (the reducer's `switch`).

---

<sub>05 · DECISIONS</sub>

## What earned an ADR

Nine decisions earned a written record — anywhere a future contributor would otherwise ask "why this and not the other thing?" Full text is in [`docs/ADRs.md`](docs/ADRs.md); the one-liner index is below.

| | Decision | Why it earned an ADR |
|---|---|---|
| **001** | Hand-rolled MVI, not TCA | Framework cost > value at N=2 screens; one-way flow + an explicit intent enum capture the essentials without ceremony. |
| **002** | iOS 17 deployment target | Each iOS-17-only API saves 30–60 lines of `#available` branching versus iOS 16. |
| **003** | Function-style clients, not protocols | At N=1 operation per client, protocols add ceremony with no payoff. Includes a 3-way comparison vs the generic-Endpoint approach and a migration sketch for past N=4 endpoints. |
| **004** | Sweep I reverted | A "math-equivalent" parallax rewrite interacted badly with `.scaledToFill` on the hero. Honest revert. |
| **005** | Dismiss-no-refetch guard | Status-gated `.appeared` prevents skeleton flash on pop-back from detail; retry stays unconditional. Pinned by a regression test. |
| **006** | Scene-phase staleness — 5 minutes | Balances "briefly switched to Messages" (no refetch) against "came back hours later" (real stale-data risk). |
| **007** | Value-bound animation, not `PhaseAnimator` | The iOS 18 zoom transition recreates the destination view, which desyncs the phase index from a preserved `@State` trigger. Value binding has no internal state to desync. |
| **008** | Composition-root value bundling all clients | One file, full dependency graph; previews default to fixture clients so they never accidentally hit staging. |
| **009** | Sectioned horizontal carousels for Hotel Listings | Hospitality search is image-led; the spec's vertical list loses the curation signal that makes a day-pass marketplace feel different from a generic directory. |

---

<sub>06 · FEATURES</sub>

## What each surface owns

Three feature surfaces. Each gets a lead sentence, the notable design choice, an edge case worth flagging, and a test count.

### Search — *autocomplete with a real failure mode*

**A search bar with autocomplete and five primary states.** Idle, loading, loaded, empty, failed — plus a dedicated *null-coordinates* failure for places where the staging API doesn't have lat/lng. Brooklyn, Florida is the canonical example.

The 500 ms debounce runs through an injected `ContinuousClock`, so tests don't actually have to sleep. The failure-state CTA for the null-coord case is "Search a nearby city" instead of a generic "Try Again" loop that would re-pick the same offending place.

> **Maestro caught a real bug here.** In landscape, the on-screen keyboard covered the retry CTA in failed and empty states. Fixed by auto-dismissing the keyboard on status change.

<sub>**Tests** — 11 reducer · 21 spec compliance · 6 direct live-client</sub>

### Hotel listings — *sectioned carousels, not the spec's vertical list*

**Above the fold: a parallax stretchy hero, a filter chip row, then sectioned horizontal carousels.** `Top picks` (≤5 by rating) · `Within walking distance` (≤1.5 mi) · `Best value` (cheapest 5) · `All` fallback.

The section pipeline is a pure builder cached on the loaded state — it rebuilds only when the hotels or the active filter change, never per render. Filters cover All / Pool / Spa / Adults / Pets / Wellness via simple string matching against the hotel's product name and primary vibe; the API doesn't expose its own filter categories.

Cache warming runs in two windows: the first 30 cards when the listings load, the next four detail-carousel images when the user taps a card.

> **Why this and not a vertical list.** Hospitality search is image-led. Full reasoning in **§12** and [ADR-009](docs/ADRs.md).

<sub>**Tests** — 5 reducer · 11 section-pipeline · 9 direct live-client</sub>

### Hotel detail — *the signature animation surface*

**A pushed scene that morphs in from the tapped card.** On iOS 18, the morph uses matched-transition-source + the system zoom navigation transition. On iOS 17, it falls back to `matchedGeometryEffect` + a `ZStack` overlay. Both paths compile against the iOS 17 SDK via an `@available` gate.

The sticky header runs a parallax on pull-down, with a damped scale. Dismiss is a drag-throw with a rubber-band response, driven by `CADisplayLink` so it runs at the native refresh rate — 120 Hz on ProMotion.

The image carousel inside uses a peek + mid-snap layout; its caching processor matches what the Kingfisher prefetch uses upstream, so the morph never has to decode an image at run time.

<sub>**Pinned by Maestro flows** — `14-card-detail-morph-spring-envelope`, `15-swipe-down-dismiss-rubber-band`, `20-hero-stretch-pulldown`, `21-content-fade-in-detail`</sub>

---

<sub>07 · DATA</sub>

## Real API quirks worth knowing

Things the staging API does that shaped the model layer:

- The autocomplete response is a **top-level array**, not wrapped in an object.
- Some places (Brooklyn FL is the canonical one) return null lat/lng. Tapping them would send `0,0` to the hotels endpoint and return unrelated results — the VM guards and shows a dedicated failure state instead.
- **Integer `id` collisions are real.** Newport Beach and Newport Coast share `id=236` because Coast is an alias. The model maps `Identifiable.id` to the stable string `objectID` so `ForEach` doesn't silently drop duplicates.
- The hotels response wraps currency as a nested object, encodes images as nested URL records (the decoder picks the largest), and ships both a human-friendly `rating` and a frequently-zero `avg_rating` — the model uses `rating`. Cheapest price is computed from the products array.
- **Lossy array decode is the default.** One malformed row drops to nil rather than breaking the whole response.

---

<sub>08 · CHOICES</sub>

## Technical choices

A flat matrix of the decisions you'd otherwise have to dig through code to reconstruct. Each row points to an ADR where there's depth worth defending.

| Concern | Choice | Why |
|---|---|---|
| **UI framework** | SwiftUI primary, UIKit at 6 specific seams | Spec requires SwiftUI primary; UIKit appears only where SwiftUI doesn't yet reach — status-bar coordination on iOS 17, CoreAnimation-side chip pulse, scale-aware hairlines, the Metal/MPS image grader, and the 120 Hz drag-throw spring. |
| **Concurrency** | `async/await` + `Task` + `ContinuousClock` | An injectable clock lets the 500 ms debounce be tested without timing flakes. |
| **Networking** | `URLSession` wrapped in a `Sendable` transport seam + one orchestration helper | Two endpoints don't justify Alamofire. The helper holds the cross-cutting work in one place. |
| **State management** | Hand-rolled MVI with `@Observable` | See **§4** for the full reasoning. |
| **Dependency Injection** | Manual constructor injection + a composition-root value | One file to read for the full dependency graph. [ADR-008](docs/ADRs.md). |
| **Client shape** | Function-style: `Sendable struct` of `@Sendable` closures | Swap-for-test is one line. [ADR-003](docs/ADRs.md). |
| **Navigation** | `NavigationStack(path:)` with a value-based `AppDestination` | Type-safe deep links; mutations flow through the reducer. |
| **Data modeling** | `Codable` with explicit `CodingKeys` | Auto-conversion is wrong for this wire shape (mixed-case keys). |
| **Defensive decoding** | Lossy array decode by default | One malformed row drops to nil rather than breaking the response. |
| **Image caching** | Kingfisher 8.x + a custom editorial-grade processor (Core Image + Metal/MPS fallback) | The grade runs once per URL, cached by processor identifier. Two cache-warming windows. |
| **Minimum iOS** | 17.0 | Lifted from the spec floor of 16 to use `@Observable`, `ContentUnavailableView`, the value-based path, and `ContinuousClock`. [ADR-002](docs/ADRs.md). |
| **Localization** | `String(localized:)` with `defaultValue:` for every user string | A catalog drops in cleanly; a Spanish stub exists to show that resolution works. |

### UIKit drops

Six deliberate seams where UIKit earns its keep:

| Seam | UIKit surface | Why |
|---|---|---|
| Status-bar bridge | `UIHostingController` with `preferredStatusBarStyle` | No native SwiftUI status-bar coordination during the morph on iOS 17. Gated to iOS < 18. |
| Transition adapters (4 files) | `UIPresentationController` + percent-driven + animated transitioning | iOS 17 fallback morph scaffolding. |
| Filter-chip pulse | `UIViewRepresentable` over `CALayer` + `CABasicAnimation` | Frame-precise, vBlank-aligned — distinct from SwiftUI's transaction system. |
| Hairline tokens | `UIScreen.main.scale` | Physical-pixel-crisp hairline width. |
| Editorial-grade processor | `UIImage` + Core Image + Metal/MPS | Kingfisher's processor takes `UIImage`. Metal on cache miss; Core Image as fallback. |
| Drag-throw spring | `CADisplayLink` | 120 Hz spring integration on ProMotion. [ADR-007](docs/ADRs.md). |

---

<sub>09 · TESTING</sub>

## Verification at two layers

```
unit:    120 tests across 12 files · ~20s · iPhone 16 Pro / iOS 18
maestro: 81 flows · real staging API · launch-arg-injected failure variants
```

**The unit suite** covers reducer behavior per feature; spec-pinning tests for the 500 ms debounce timing, the dismiss-no-refetch regression, scene-phase staleness, and presentation transitions; the transport seam (stubbed via `URLProtocol`); every URL endpoint matched against the spec verbatim (percent-encoding and CJK included); every `URLError` mapping; direct tests against the live client factories — so the orchestration helper is verified end-to-end, not just through the view-model seam; the section-builder pipeline; the logging surface; and decoder tests against real API fixtures plus deliberately-broken inputs for both `Place` and `Hotel`.

### Maestro by category

| Band | Count | Coverage |
|---|---|---|
| State cycles | 11 | Happy path, empty/clear/rapid-typing, null-coord guard, CJK input, landscape, failed-then-retry on both endpoints, hotels empty, row-field verification, comprehensive visual audit |
| Animation audits | 10 | Stretchy hero, transitions, morph spring envelope, swipe-down dismiss (rubber-band + commit), search-pill blur, peek carousel mid-snap, filter chip mid-transition, hero pulldown, content fade-in |
| Filter chips | 6 | Spa, Adults, Pets, Wellness, empty result, reset |
| Retry recoveries | 2 | Search and hotels — both exercise the toggle-recovery-on-retry launch arg |
| Loading skeletons | 2 | Search and hotels |
| Dark mode | 10 | All states × both screens × detail expanded × empty filter |
| XXL Dynamic Type | 5 | All states |
| Landscape coverage | 7 | Search and hotels failure/empty states + detail expanded + empty filter |
| German locale | 3 | Long-string truncation verification |
| Orphan-code regression | 4 | Verifies deleted UI surfaces are not mounted |
| Edge cases | 6 | Pull-to-refresh absence, rapid-type-then-clear, debounce collision, offline (search + hotels), slow 3G image loading |
| VoiceOver | 3 | Idle, hotel row, detail close |
| Reduce Motion / Bold Text / Contrast / AX5 | 7 | All major motion + accessibility traits |
| iPad | 2 | Hotels loaded + detail expanded (out of spec but flow-verified) |
| Other | 3 | Coordinate-tap regression (system back button), image-load timing |

Flows use real on-screen text assertions, named screenshot checkpoints, and waits with timeouts. The runner exits non-zero on any missed assertion or app crash — the flow IS the test, no separate diff or compare setup is needed. Launch arguments inject failure-state clients so every error UI is reachable without disrupting the staging API.

### Three real bugs Maestro caught

- **Landscape keyboard covered the retry CTA** in compact-height layouts. Fixed by auto-dismiss on status change.
- **iOS 26 + Maestro 2.5.1** — the Maestro driver can't walk the iOS 26 SwiftUI accessibility tree (`assertVisible` on body text fails while the app looks identical on iOS 18). Maestro work is pinned to the iOS 18 sim until Maestro fixes this upstream.
- **Null-coordinate dead-end** — selecting an alias-only place would otherwise trap the user in a re-failure with no way out. Pinned by paired happy-path and null-coords flows.

### Snapshot testing

Not implemented in this submission. Listed in **§14** — `swift-snapshot-testing` for the state × portrait/landscape × light/dark matrix would close the visual-regression gap that Maestro's text-only assertions can't cover.

---

<sub>10 · AUTOMATION</sub>

## Continuous Integration

A GitHub Actions workflow at [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Three jobs:

| Job | Trigger | Duration | Gate |
|---|---|---|---|
| **Unit tests** | Every push + PR | ~5 min | Full 120-test suite on iPhone 16 Pro / iOS 18 |
| **Maestro smoke** | Every push + PR (after unit tests) | ~5–10 min | Five critical flows |
| **Maestro full** | Weekly + manual dispatch | ~30–40 min | All 81 Maestro flows |

`xcresult` bundles and Maestro screenshots upload as workflow artifacts on failure. Concurrency control cancels in-progress runs when a new commit is pushed to the same branch. Maestro in CI uses the same fail-on-missed-assertion model as running locally — flows hit the real staging API, so a staging outage will fail CI (an accepted trade-off for real-world coverage; flagged in the workflow's top comment).

---

<sub>11 · ACCESSIBILITY</sub>

## Accessibility posture

**What's in.** VoiceOver labels on every interactive element. Five concrete moves:

- Hotel cards combine with `.accessibilityElement(children: .combine)` so the rotor reads each card as a single element.
- Section headers carry the `.isHeader` trait so VoiceOver users can rotor-skim section by section.
- Dynamic Type is respected through `xxLarge` and into the accessibility sizes via semantic font styles.
- Empty and failed states use `ContentUnavailableView` — iOS 17 native, with built-in traits.
- Light and dark mode resolve through Asset Catalog semantic colorsets with both appearance variants.

All of the above is pinned end-to-end by dedicated Maestro flows for VoiceOver navigation, AX5 layout, Reduce Motion, Bold Text, and Increase Contrast.

**What's honestly missing.** No `AccessibilitySnapshot` integration for label/trait regression catching (deferred to §14). No automated VoiceOver navigation-order tests beyond the Maestro coverage. Dark-theme contrast isn't formally WCAG-audited. The filter chip and clear-search tap areas sit on the HIG 44 pt boundary — flagged for an explicit audit pass.

---

<sub>12 · DEVIATION</sub>

## Hotel listings rendering — deliberate deviation

The interview prompt suggests *"vertical list (e.g., `List` or `LazyVStack` inside a `ScrollView`)"* for Screen 2. This app ships **sectioned horizontal carousels** instead. Three reasons:

- Hospitality search is image-led. Wide, photo-dominant cards in a peek-carousel give every result equal first-class visual real estate — the rhythm of 2026-era travel apps (Airbnb, Hopper, Booking.com).
- Sectioning by editorial axis (`Top picks` / `Within walking distance`) puts curation up front, which is what differentiates a day-pass marketplace from a generic hotel directory.
- A pure vertical list is the strictly compliant choice; this deviation prioritizes the UX impression over verbatim spec adherence, which felt like the right founding-engineer call to call out explicitly.

Each card still shows hotel name, image, rating, and price — the spec's *"most relevant product/price information"* — so the information surface matches even when the layout doesn't. Documented in [ADR-009](docs/ADRs.md).

---

<sub>13 · LIMITATIONS</sub>

## Known limitations

- **Pagination** — both endpoints accept `limit` + `offset`; the UI doesn't paginate yet.
- **Pull-to-refresh** on hotel listings is currently disabled (pinned by a Maestro flow that checks for its absence).
- **Offline behavior** — no caching of last-seen results; a network drop returns the user to `.failed` with no stale-data fallback.
- **Localization** — plumbing is in place; non-English catalogs aren't shipped yet.
- **Extended product surface** — each hotel has multiple products with tiered prices; the UI shows only the cheapest + the top-level product name.
- **App icon + launch screen** — placeholder only.
- **Snapshot testing** — not implemented; deferred to **§14**.
- **iOS 26 + Maestro** — Maestro 2.5.1 can't walk the iOS 26 accessibility tree; Maestro work is pinned to the iOS 18 sim until Maestro fixes this upstream.
- **Recording infrastructure** — `simctl recordVideo` is broken on the current Xcode toolchain; the morph + parallax videos in **§2** require QuickTime manual recording until that gets fixed upstream.

---

<sub>14 · NEXT</sub>

## With more time

Roughly in order of return-on-time:

1. **Pull-to-refresh + pagination** on hotel listings via `refreshable {}` + offset bumping, with VM state for `loadingMore` and an infinite-scroll trigger threshold. ~2–3 h.
2. **Snapshot test suite** — `swift-snapshot-testing` across every state × Search/Listings × portrait/landscape × light/dark. `AccessibilitySnapshot` on top for label and trait regressions. ~3–4 h.
3. **Migration past N=4 endpoints** — a generic `Endpoint<Response>` + a single dispatcher (sketched in [ADR-003](docs/ADRs.md)). Centralizes retry, auth, telemetry. Not protocols.
4. **Swift 6 typed throws** at the client signatures, so the error taxonomy lives in the type system instead of runtime downcasts.
5. **`AsyncSequence` debounce** via Async Algorithms instead of the imperative `Task` + clock sleep.
6. **Maestro device matrix in CI** — iPhone SE / 15 / 17 Pro Max × portrait/landscape × themes on PRs.
7. **Snapshot regression in CI** — a fourth workflow job with diff images uploaded as artifacts.
8. **Recording-factory logger** so unit tests can assert on logger emissions per status transition.
9. **Pre-commit hooks** (SwiftFormat or SwiftLint) so the conventions don't drift.
10. **Localization catalogs** for at least Spanish and French.
11. **Performance traces** for the morph hot path (Instruments + a target frame budget pinned in CI).
12. **iOS 26 retest** once Maestro fixes the accessibility-tree gap.
13. **Video recording workaround** — QuickTime or `ffmpeg avfoundation` so the demo videos ship as real motion.

---

<sub>15 · LAYOUT</sub>

## Project layout (reference)

```
Sources/
├── App/                       @main + composition root + iOS 17 morph adapters + status-bar bridge
├── Models/                    Place · Hotel · Currency (+ preview fixtures in their own files)
├── Networking/                Transport seam + orchestration helper + typed HTTP primitives + Codable bodies + lossy decoding + error taxonomy + actor-backed test counter
├── Features/
│   ├── Search/                State + Intent + ViewModel + View
│   ├── HotelListings/         Same shape, plus the section-builder pipeline
│   └── HotelDetail/           Pushed-mode scene + CADisplayLink drag-throw
├── DesignSystem/              Two-tier design tokens (palette → theme) + reusable components
├── ImageCaching/              Kingfisher wrapper + editorial-grade processor (Metal/MPS)
├── Logging/                   Function-style logger + typed event names
├── Routing/                   Single value-based destination enum
├── Strings/                   `String(localized:)` namespace + per-feature error-message factories
└── Resources/                 Asset catalog (light/dark semantic colorsets, fonts, icons)

Tests/
├── Per-feature ViewModel tests        Reducer behavior
├── SpecComplianceTests                Spec-pinning (debounce, dismiss-no-refetch, staleness, transitions)
├── Live-client tests                  Direct .live factory coverage via stubbed transport
├── Transport + endpoints + constants  URLProtocol-stubbed transport, URL spec pins, boundary constants
├── Section-builder + logging + decoders   Pipeline pins, logging surface, defensive Codable
└── Fixtures/                          Real staging JSON for decoder tests
```

---

<sub><a href="ARCHITECTURE.md">ARCHITECTURE.md</a> · <a href="docs/ADRs.md">docs/ADRs.md</a> · <a href=".github/workflows/ci.yml">CI workflow</a> · <a href="https://github.com/matthewharrilal/mobile-interview-test/actions">CI Actions tab</a> · <a href=".maestro/">Maestro flows</a> · <a href="ux-research/">UX research</a></sub>
