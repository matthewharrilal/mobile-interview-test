# Build Brief — Airbnb-style transitions in ResortPassApp

## Mission

Replace the existing system `.sheet`-based hotel detail with three custom transitions matching Airbnb's iOS app, frame-by-frame:

1. **Search-bar tap → search-active overlay** — blur+crossfade with shared search-pill identity (~200ms ease-in-out, NO spring).
2. **Carousel card tap → detail expansion** — matched-geometry expansion of the tapped card to fill the screen (~150ms, near-critical damping). Background blurs and dims; content fades in 80–100ms after geometry settles.
3. **Swipe-down dismiss** — gesture-driven with rubber-band before commit, 1:1 finger tracking after threshold, velocity-throw on release. Explore screen un-blurs as detail clears.

Source-of-truth analysis is in `ux-research/03-airbnb-hilton-patterns.md`. Frame-level details and timing are documented there and in conversation history.

## Project facts (do not relitigate)

- **Location:** `~/Desktop/XcodeInstall/ResortPassApp/`
- **Architecture:** MVI (`@Observable @MainActor` view models, `<Feature>State` + `<Feature>Intent` + `<Feature>ViewModel.send(_:)`)
- **iOS deployment target:** 17.0
- **Swift:** 5.9
- **Image cache:** Kingfisher via `CachedAsyncImage` wrapper
- **Project gen:** xcodegen (`project.yml`); regenerate with `xcodegen generate` after adding files
- **Build:** `xcodebuild -scheme ResortPass -destination 'platform=iOS Simulator,name=iPhone 15' build`
- **UI testing:** Maestro flows under `.maestro/`

## Existing code to build on (read these before touching anything)

- `Sources/Features/Search/Search.swift` — `SearchState`/`SearchIntent`/`SearchViewModel`; pattern to follow
- `Sources/Features/HotelListings/HotelListings.swift` — same pattern; has `Filter` enum and sectioned layout
- `Sources/Features/HotelListings/HotelListingsView.swift` — current host; `@Namespace private var heroNamespace` at line 12; cards already wear `matchedGeometryEffect(id: "card-\(section.id)-\(hotel.id)", in: heroNamespace)` at line 234
- `Sources/DesignSystem/Components/HotelImageCarousel.swift` — image carousel inside detail
- `Sources/DesignSystem/Components/StretchyHero.swift` — `stretchyHero()` modifier
- `Sources/DesignSystem/Tokens/Theme.swift` — design tokens (Color, Spacing, Typography, etc.). USE THESE. Do NOT hard-code colors or spacing.
- `Sources/Models/Hotel.swift`, `Place.swift`, `Currency.swift`
- `Sources/Routing/AppDestination.swift` — value-based navigation enum

## Hard rules

1. **Commits:** terse, human-style, imperative mood. NO `Co-Authored-By` trailer. NO Claude footer. NO AI attribution of any kind. Example: `Replace .sheet detail with matched-geometry expansion`.
2. **MVI invariant:** state is `private(set)`. Only `send(_:)` mutates it. Per-frame gesture state lives in SwiftUI `@State` in views, NOT in the view model. Commit moments (tap, release-past-threshold) flow through `send(_:)`.
3. **Theme tokens, not magic numbers** for colors and spacing. Animation durations and spring values may be inline (they're behavior, not design).
4. **No new dependencies.** Kingfisher is in. Don't add SnapshotTesting, Lottie, etc.
5. **Build before claiming done.** Every worker must run `xcodebuild ... build` to verify their slice compiles before marking the task completed. Integration agent re-runs the full build at the end.
6. **Audit before claiming done (continuous audit infrastructure).** See `12-continuous-audit.json` and `09-auxiliary.md`. Every feature/scaffold task is subject to four-dimension audits (D1 hygiene, D2 architecture, D3 senior judgment, D4 system) firing AFTER every feature/sub-criterion completes. Workers run `scripts/audit.sh all <target>` themselves; team-lead spawns four auditor agents per worker on completion. Audit findings become `Remediate D{n}: …` tasks blocking final acceptance.

## Continuous audit — Definition of Done (inline; layer 2 of the audit infrastructure)

Every feature, scaffold, and transition task in this build MUST satisfy ALL of the following before being marked completed. This list is reproduced verbatim in each task's description and is non-negotiable.

1. Code compiled — `xcodebuild -scheme ResortPass build` passes (D4 mechanical).
2. `scripts/audit.sh hygiene <target>` exits 0 OR all findings filed as `Remediate D1: …` tasks before marking completed.
3. `scripts/audit.sh architecture <target>` exits 0 OR all findings filed as `Remediate D2: …` tasks.
4. `scripts/audit.sh judgment <target>` exits 0 OR all findings filed as `Remediate D3: …` tasks.
5. `scripts/audit.sh system <target>` exits 0 (build passes) AND existing Maestro flows still execute on the affected surface.
6. Self-attestation: worker has reviewed their own diff against D1–D4 dimensions and either fixed in place or filed remediations.
7. After worker marks the task `completed` via `TaskUpdate`, the team-lead spawns four auditor agents (one per dimension) targeting the worker's commit. Audit findings become new `Remediate D{n}: …` tasks that block final acceptance of the feature.

The four audit dimensions are documented in full in `ux-research/team/12-continuous-audit.json`. The dispatch protocol, remediation template, and audit-log format are in `ux-research/team/09-auxiliary.md`. Read both before starting your task.

## Animation parameters (reverse-engineered from frames; tune by feel)

### Transition 1 — search-pill blur-crossfade
- Duration: ~200ms
- Curve: `.easeInOut(duration: 0.2)` (NOT a spring)
- Backdrop blur: 0 → 24pt
- Backdrop opacity dim: 1.0 → 0.5
- Search pill: shared identity via `matchedGeometryEffect(id: "searchPill", in: ns)`
- Keyboard: appears as a SEPARATE event ~220ms after the modal lands (via `Task.sleep(220ms)` then `fieldFocused = true`)

### Transition 2 — card-to-detail matched-geometry expansion
- Geometry duration: ~150ms
- Curve: `.spring(response: 0.25, dampingFraction: 0.95)` (near-critical damping, no overshoot)
- Background blur on explore: 0 → 24pt
- Background opacity dim: 1.0 → 0.5
- Content fade-in inside detail: 80–100ms AFTER geometry settles (so total perceived ~250ms)
- Card during transition has `.shadow(color: .black.opacity(0.18), radius: 24, y: 12)` for "lift" cue

### Transition 3 — swipe-down dismiss
- Phase 1 (rubber-band before commit): first ~100pt of drag stretches hero only, doesn't translate card
- Phase 2 (1:1 tracking): after threshold, card follows finger directly
- Phase 3 (release):
  - Commit if: drag > 200pt OR predicted velocity > 600pt/s downward
  - Snap back if: neither commit condition met → `.spring(response: 0.4, dampingFraction: 0.7)` to dragOffset = 0
  - Throw on commit: `.interpolatingSpring(stiffness: 200, damping: 25, initialVelocity: velocity / throwDistance)`
- Rubber-band curve: `(1 - 1/(offset * 0.55 / range + 1)) * range`
- Explore screen un-blurs LIVE as detail clears (lift `dragProgress` 0→1 to a binding the parent reads)

## Phase plan

### Phase 1 — Architect (solo, sequential)
- Read existing code thoroughly
- Decide integration strategy: replace `HotelListingsView` body? Wrap it in a new shell? Add overlay layers?
- Write `ux-research/team/01-integration-plan.md` documenting the decision and the file boundaries between workers
- Build the new shell (`ExploreShell` or modified `HotelListingsView`) with ZStack composition for browsing/searchActive/detailExpanded layers
- Add the `searchPill` `matchedGeometryEffect` source identity at the top of the explore content
- Create skeleton `Sources/Features/HotelDetail/HotelDetailScene.swift` with the namespace contract and matched IDs (no animation logic yet — workers fill in)
- Create skeleton `Sources/Features/Search/SearchActiveOverlay.swift` for Transition 1 surface
- Run `xcodegen generate && xcodebuild ... build` — must pass
- Commit: `Scaffold transition shell: ZStack composition, detail scene, search overlay`

### Phase 2 — Three workers in PARALLEL
**Worker A — Transition 1 (search-pill blur-crossfade):**
- Fill in `SearchActiveOverlay.swift` (or rename per architect's plan)
- Wire blur + dim + matched search pill identity
- Delayed keyboard via `Task.sleep(220ms)` + `@FocusState`
- Tap-to-dismiss outside the pill, or back chevron
- Commit: `Implement search-pill blur-crossfade overlay`

**Worker B — Transition 2 (card → detail matched expansion):**
- Replace `.sheet(item: $presentedHotel)` in `HotelListingsView` with overlay-driven `HotelDetailScene`
- Wire matched-geometry between source `CompactHotelCard` and detail's hero image (use existing IDs)
- Background blur + dim on browsing layer when detail is expanded
- Content fade-in inside detail with 80ms delay after geometry settles
- Commit: `Replace detail sheet with matched-geometry expansion`

**Worker C — Transition 3 (swipe-down dismiss + parallax):**
- Add `DragGesture` to `HotelDetailScene` hero region (NOT full detail — must not eat ScrollView pan)
- Implement rubber-band, threshold detection, velocity throw, snap-back
- Hero parallax: `frame(height: heroBaseHeight - max(0, dragOffset * 0.3))`
- Publish `dismissProgress: CGFloat` to parent so explore un-blurs live
- Commit: `Add gesture-driven dismiss with rubber-band and velocity throw`

### Phase 3 — Polish + integration
- `xcodegen generate && xcodebuild ... build` — must pass
- Run existing Maestro flows; update or add as needed for the new transitions
- Add `accessibilityReduceMotion` fallback (instant transitions when enabled)
- Implement Kingfisher prefetch on press-down (`LongPressGesture(minimumDuration: 0.05)`)
- Update `README.md` documenting the new transition system
- Final commit: `Add reduce-motion fallback, image prefetch, README updates`

## Coordination

- Read `ux-research/team/01-integration-plan.md` (architect writes it) before starting Phase 2 work
- Workers communicate via SendMessage if they hit cross-cutting concerns (especially Workers B and C sharing `HotelDetailScene`)
- Mark tasks completed via TaskUpdate as soon as the slice builds — don't batch
- If you hit a real blocker, send the team-lead a clear plain-text message describing what's blocked and what you tried
