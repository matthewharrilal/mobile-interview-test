# Audit log — rp-transitions team

Append-only running log of every audit firing per the cadence rule in `12-continuous-audit.json`. Each entry follows the format documented in `09-auxiliary.md` § 4.

---

## 2026-05-10 — audit firing (D2 only)

**Triggered by:** architect commit `87c490a` (Scaffold transition shell: ZStack composition, detail scene, search overlay)
**Commit:** 87c490a
**Target:** Sources/Features/HotelDetail/HotelDetailScene.swift, Sources/Features/Search/SearchActiveOverlay.swift, Sources/Features/HotelListings/HotelListingsView.swift (architect's portion)
**Dimensions audited:** D2 (architecture & abstraction) — other dimensions handled by sibling auditors
**Mechanical results:**
- D2: fail with 1 finding — `HotelListingsView.swift` is 520 LOC (cohesion file-size signal > 500). Premature-abstraction grep clean. Module-boundary grep clean. Cross-feature import grep clean.

**Judgment results:**
- D2 (auditor-D2-architect): 0 critical, 0 major, 4 minor

**Remediation tasks filed:** none

**Minor observations (no task):**
- `Sources/Features/HotelListings/HotelListingsView.swift` (520 LOC) — **cohesion**. The host now combines listings rendering, the new ZStack shell, the `PresentationLayer` state machine, the new `searchPillBar` chrome, the `exploreBlurRadius`/`exploreOpacity` computeds, and the unrelated `HotelDetailPreview` struct. The shell-composition pieces belong here per the integration plan (host owns the namespace + layer composition), but `HotelDetailPreview` is a context-menu helper that has nothing to do with the host shell — natural candidate to move into `Sources/Features/HotelDetail/` (or a `HotelDetailPreview.swift` peer file). Doing so would drop the host back under the 500-LOC threshold.
- `Sources/Features/HotelDetail/HotelDetailScene.swift:124-135` + `Sources/Features/Search/SearchActiveOverlay.swift:52-58` — **missing abstraction (forward-looking)**. Both files render a chrome chevron button with identical font sizing (`.system(size: 15, weight: .semibold)`) and `Theme.Color.textPrimary` foreground, differing only in icon (`chevron.down` vs `chevron.left`) and background (`.ultraThinMaterial in Circle()` vs none). Two instances is the threshold where extracting a `GlassChevronButton(direction:onTap:)` (or modifier) in `Sources/DesignSystem/Components/` becomes profitable — flag for Workers A/B/C to coordinate when they wire dismiss affordances.
- `Sources/Features/HotelListings/HotelListingsView.swift:70-71` + future `SearchActiveOverlay` blur — **missing abstraction (deferred)**. The architect's `.blur(radius: exploreBlurRadius).opacity(exploreOpacity)` pattern with the `(1 - dismissProgress) * 24` and `1.0 - (1 - dismissProgress) * 0.5` formulas will repeat once Worker A wires blur+dim into `SearchActiveOverlay` (and the integration plan also has Worker B re-tuning these). Currently only one site, so extraction now would be premature — but Worker A/B should extract a `.recessedBackground(intensity: CGFloat)` view modifier into `Sources/DesignSystem/` rather than copy the formulas. Pre-emptive flag, not a current violation.
- `Sources/Features/HotelListings/HotelListingsView.swift:22, 86-88` — **dependency direction / module boundary (informational)**. The host now owns `searchViewModel: SearchViewModel` and references `HotelDetailScene` + `SearchActiveOverlay` directly, making `Features/HotelListings/` structurally aware of `Features/HotelDetail/` and `Features/Search/`. Mechanical cross-feature-import grep is blind to this because all three live in the same Swift module. Direction is still downward (View → ViewModel → Model — no inversions), and the integration plan (`01-integration-plan.md` § "Decision: modify HotelListingsView in place (no new shell)") explicitly considered and rejected lifting this into a dedicated `ExploreShell`. Documented so future workers don't perpetuate sibling-feature references in the host without the same justification, and so the rename `HotelListingsView → ExploreShell` stays on the radar for a future refactor pass.

**D2 conclusion:** No critical or major findings. The architect's structural decisions are coherent: single namespace, explicit shell-composition state machine, closed-unit `HotelDetailScene` and `SearchActiveOverlay` contracts that respect the worker boundaries in `01-integration-plan.md`. The four observations above are minor and either trace back to a documented architectural trade-off (host-as-shell) or anticipate copy-paste that hasn't materialized yet.

---

## 2026-05-10 — audit firing (D1 only)

**Triggered by:** architect commit `87c490a` (Scaffold transition shell: ZStack composition, detail scene, search overlay)
**Commit:** 87c490a
**Target:** Sources/Features/HotelDetail/HotelDetailScene.swift, Sources/Features/Search/SearchActiveOverlay.swift, Sources/Features/HotelListings/HotelListingsView.swift (architect's portion)
**Dimensions audited:** D1 (code hygiene) — other dimensions handled by sibling auditors
**Mechanical results:**
- D1: fail — 3 raw failure categories. DRY duplicate signatures (`failedState`, `loadedState`, `placeRow`); magic-number scan flagged 20 sites (most pre-existing and out of scope); commented-code heuristic flagged 6 sites (all confirmed false-positive — prose comments containing punctuation). Singletons clean. Naming-convention grep clean. Mechanical dead-code scan clean.

**Judgment results:**
- D1 (auditor-D1-architect): 0 critical, 2 major, 5 minor

**Remediation tasks filed:**
- Remediate-D1-SearchActiveOverlay-duplicates-SearchView (#1) — DRY major
- Remediate-D1-hero-height-360-magic-number (#2) — magic-number major

  Note: `addBlocks: ["1"]` from the dispatch protocol could not be honored at filing time — the task list contained only the two new remediations and no architect scaffold task to block. Team-lead should wire the dependency once the parent feature task exists in the system.

**Minor observations (no task):**
- `Sources/Features/HotelDetail/HotelDetailScene.swift:110` — **magic number**. `HStack(alignment: .firstTextBaseline, spacing: 4)` uses spacing literal `4`; `Theme.Spacing.xs` is exactly 4 and should be referenced for consistency.
- `Sources/Features/Search/SearchActiveOverlay.swift:149` — **magic number**. `.padding(.leading, 64)` divider inset is copied from `SearchView.swift:153`. Subsumed by the SearchView dedup task; if dedup is deferred, lift to a named constant in the meantime.
- `Sources/Features/Search/SearchActiveOverlay.swift:162` — **magic number**. `.frame(width: 32, height: 32)` icon-container size literal (also copied from existing SearchView pattern).
- `Sources/Features/Search/SearchActiveOverlay.swift:168` — **magic number**. `VStack(alignment: .leading, spacing: 2)` uses spacing literal `2`, which is off-grid (smallest Theme step is `xs = 4`). Cosmetic, single instance.
- **Naming consistency**: matched-geometry IDs mix `"searchPill"` (lowerCamelCase, constant) and `"card-\(section.id)-\(hotel.id)"` (kebab-with-interpolation, parameterized). Defensible split (constant vs parameterized) and the kebab convention is pre-existing — but worth documenting in `01-integration-plan.md` so future morph IDs pick a side intentionally.

**Mechanical false-positives confirmed:**
- All 6 commented-code heuristic hits in scope are prose doc comments containing punctuation — none are commented-out code.
- Magic-number flags on `HotelListingsView.swift` lines 277/331/334/417/430/431/437/482/504 are pre-existing code untouched by 87c490a; not in this audit's scope. (Line 63 in `HotelDetailScene` IS in scope and is filed as task #2.)
- Magic-number flags on `SearchView.swift` lines 122/126/127/130/131/153/169 are pre-existing; not in scope, but the architect's overlay copies them — addressed by the DRY remediation (task #1).
- DRY duplicate-signature flags for `failedState(_ message: String)` are partially out of scope (the `HotelListingsView` one is pre-existing, and the third hit is `SearchView` which is pre-existing). The duplication that IS in scope is `SearchActiveOverlay` ↔ `SearchView` — covered by task #1.

**Cross-dimension concerns noticed (input for sibling auditors):**
- The DRY finding (task #1) is also a D2 missing-abstraction concern: extracting a shared `SearchResultsContent` is structural, not just hygiene. D2 auditor's "missing abstraction (deferred)" pattern is the same shape.
- The hero-height-360 token (task #2) intersects D4 cross-criterion-consistency: Worker C's brief uses `heroBaseHeight - max(0, dragOffset * 0.3)` for parallax — naming the token `heroBaseHeight` aligns the two surfaces by name, not just value.

**D1 conclusion:** Two major findings warrant remediation tasks (one structural duplication, one shared-dimension magic number); five minor findings logged. The architect's hygiene is otherwise solid: singletons clean, no commented-out code, no dead code, no naming violations, and the only in-scope magic numbers are cosmetic offsets and the shared-dimension hero height already covered by task #2.

---

## 2026-05-10 — audit firing (D3 only)

**Triggered by:** architect commit `87c490a` (Scaffold transition shell: ZStack composition, detail scene, search overlay)
**Commit:** 87c490a
**Target:** Sources/Features/HotelDetail/HotelDetailScene.swift, Sources/Features/Search/SearchActiveOverlay.swift, Sources/Features/HotelListings/HotelListingsView.swift (architect's portion)
**Dimensions audited:** D3 (senior judgment & technical debt) — other dimensions handled by sibling auditors
**Mechanical results (D3):**
- anti-patterns: pass (no `try!` / `as!` / `fatalError(` / force-unwrap in scope)
- code smells: pass (no funcs > 5 params)
- complexity: 2 long-function flags — `parallaxHeader` 68 LOC, `sectionView` 64 LOC. Both pre-existing; architect's diff did not materially change either body. Out of strict scope.
- file/function size: fail — `HotelListingsView.swift` is 520 LOC (up from ~353 pre-commit, +254/-87 in this diff). Crossed the 400-LOC threshold by 30%.
- hidden state: 0 `static var`. Advisory `@State`-in-Features list emitted; judgment review below covers each new occurrence.

**Judgment results:**
- D3 (auditor-D3-architect): 0 critical, 2 major, 4 minor

**Remediation tasks filed:**
- Remediate-D3-presentation-State-violates-MVI-commit-state-invariant (TaskCreate returned id #3) — addBlocks: ["1"] requested but TaskUpdate errored "Task not found"; team-lead to confirm linkage.
- Remediate-D3-HotelListingsView-520-LOC-extract-Preview-and-PresentationLayer (TaskCreate returned id #1) — addBlocks: ["1"] applied per TaskUpdate "Updated task #1 blocks"; team-lead to verify the link points at the architect feature task and not at the new remediation itself.

**Per-item judgment review:**

1. **anti-patterns** — clean. No `try!`, `as!`, `fatalError(`, or force-unwraps in any of the architect's three files. The detail's `if case .detailExpanded(let hotel, let sourceID) = presentation, case .loaded(let loaded) = viewModel.state.status` pattern is the right shape — destructured, no bangs.

2. **code smells** — mostly clean. The mechanical >5-param grep targets `func` only and missed that `HotelDetailScene`'s initializer takes 6 stored properties (hotel, currency, ns, sourceID, dismissProgress binding, onDismiss). The architect explicitly justified the extra `sourceID` parameter in `01-integration-plan.md` § "Contract for HotelDetailScene" — defensible for the cross-worker contract, but the threshold is now tight: a 7th parameter would no longer be defensible. `PresentationLayer` enum is intentional, NOT a primitive-obsession smell. The `String` `sourceID` is a typed-value-object candidate (`MatchedGeometryID`) but extraction at this scale would be premature.

3. **complexity** — both flagged functions (`parallaxHeader`, `sectionView`) are pre-existing SwiftUI view-builders the architect did not materially modify. Earned for view-builders (no extract-helper escape valve in SwiftUI without naming a sub-view). `sectionView` has natural extraction points (section header HStack, horizontal-card ScrollView) and acquired the matched-geometry + presentation-mutation paths in this diff — flagged as minor for any future polish touch.

4. **file/function size** — MAJOR finding filed. `HotelListingsView.swift` is 520 LOC. The integration plan justifies host placement (namespace adjacency to source-card identities) — but `HotelDetailPreview` (33 LOC, lines 474-507) is a context-menu helper unrelated to the host shell, and `PresentationLayer` (lines 61-65) is a clean value type. Either extraction drops the host below 400 LOC. See remediation task.

5. **hidden state** — MAJOR finding filed for `presentation: PresentationLayer`. `dismissProgress: CGFloat` is correct per-frame state per `01-integration-plan.md` (Worker C is the writer, host reads). `searchViewModel: SearchViewModel` is the established `@Observable` ViewModel pattern (with TODO for polish-phase live-client wiring — out of D3 scope). `presentation` is the outlier: a card-tap that mounts the detail layer, and a search-pill tap that mounts the search overlay, are both **commit moments** per the build brief's MVI invariant ("Commit moments (tap, release-past-threshold) flow through `send(_:)`"). The architect mutates `presentation` directly inside SwiftUI Button actions. The integration plan describes this pattern but never reconciles it against the brief — the deviation is undocumented. Remediation: route through `viewModel.send(_:)` OR add an explicit doc-comment exemption ratified at brief level. See remediation task.

**Minor observations (no task):**
- `Sources/Features/HotelDetail/HotelDetailScene.swift:20-26` — initializer takes 6 stored properties, exceeding the >5-param smell threshold. Mechanical D3 grep targets `func` only so it didn't trip. Architect justified `sourceID` in `01-integration-plan.md`; defensible, but logging because the threshold is now tight.
- `Sources/Features/HotelListings/HotelListingsView.swift:268-335` — `parallaxHeader(loaded:)` is 68 LOC. Pre-existing. Earned for the GeometryReader → ZStack(image + 3 gradients + caption) shape, but `parallaxImage` / `parallaxGradients` / `parallaxCaption` is a clean decomposition for a future polish touch.
- `Sources/Features/HotelListings/HotelListingsView.swift:343-406` — `sectionView(_:currency:)` is 64 LOC. Largely pre-existing; architect added the matched-geometry effect and `presentation = .detailExpanded(...)` mutations. Two natural extraction points (header HStack, horizontal-card ScrollView) — bundle with any future polish touch.
- `Sources/Features/HotelListings/HotelListingsView.swift:44-48, 53-56` — both initializers default `searchViewModel` to `SearchViewModel(client: .preview, logger: .silent)`. The `// TODO(polish): thread .live() SearchClient from ResortPassApp.` comment is present and integration-plan § "Polish-phase TODOs" tracks it. Acceptable scaffold-grade; flagging only so polish phase doesn't ship the preview client into production.

**Cross-dimension concerns noticed (input for sibling auditors):**
- The file-size finding (D3 task #1) overlaps the D2 cohesion observation already logged by auditor-D2-architect — same diagnosis (`HotelListingsView.swift` doing too many things, `HotelDetailPreview` extraction candidate). D3 elevates this to MAJOR because the file crossed the 400-LOC mechanical threshold.
- The `presentation` @State finding (D3 task #2) has implicit D4 cross-criterion-consistency implications: if `presentation` migrates into `HotelListingsState`, the existing MVI pattern in this codebase (`private(set)` state, `send(_:)` entry point, `@Observable @MainActor` view models) is preserved consistently. If the exemption path is taken instead, future workers may read it as license to keep new commit-state in `@State` — the brief's invariant erodes silently.

**D3 conclusion:** Two major findings warrant remediation: (1) `HotelListingsView.swift` exceeded the 400-LOC threshold with extractable leaf types still co-located, and (2) `presentation: PresentationLayer` is undocumented commit-state in `@State` that contradicts the build brief's MVI invariant. Anti-patterns clean, code smells mostly clean, complexity flags trace to pre-existing view-builders. Architect's senior judgment is otherwise solid — the contracts are explicit, the boundaries are defensible, and the deviations that exist are reasoned. Both remediations are tractable.

---
