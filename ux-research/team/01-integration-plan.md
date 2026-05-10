# Integration Plan — Airbnb-style transition shell

Architect: scaffold for tasks #2, #3, #4. This document is the contract Workers A/B/C
must read before starting their slice. If a worker disagrees, send the architect a
SendMessage before deviating — the contracts here keep the three slices from
colliding on the same file.

## Decision: modify `HotelListingsView` in place (no new shell)

The matched-geometry namespace already lives in `HotelListingsView` (line 12) and the
source identities are already on the carousel cards (line 234). Introducing a new
shell (`ExploreShell`) would force the namespace and the cards into different views,
which would either break the existing matched-geometry or require threading a
`Namespace.ID` parameter into every card-rendering helper. Both are net-negative
churn.

Instead, `HotelListingsView` becomes the host:

```
ZStack(alignment: .top) {
    exploreContent           // existing parallax + chips + sections
        .blur(...)           // 0 in browsing, ramps in detailExpanded
        .opacity(...)        // 1.0 in browsing, dims in detailExpanded

    // Floating chrome — search-pill source identity. Visible in browsing
    // and detailExpanded; hidden in searchActive (overlay shows its own pill).
    if presentation != .searchActive {
        searchPillBar
            .matchedGeometryEffect(id: "searchPill", in: ns)
    }

    // Layer 2 — search overlay (Worker A's surface)
    if presentation == .searchActive {
        SearchActiveOverlay(viewModel: searchViewModel, ns: ns,
                            onDismiss: { presentation = .browsing })
    }

    // Layer 3 — detail (Workers B + C share this surface)
    if case .detailExpanded(let hotel, let sourceID) = presentation {
        HotelDetailScene(hotel: hotel, currency: currency, ns: ns,
                         sourceID: sourceID,
                         dismissProgress: $dismissProgress,
                         onDismiss: { presentation = .browsing })
    }
}
```

The system `.sheet(item: $presentedHotel)` is removed; `presentedHotel` becomes
`presentation: PresentationLayer`. The existing `HotelDetailSheet` view body is
ported into `HotelDetailScene` and deleted from `HotelListingsView.swift`.

## Namespace strategy

One namespace (`@Namespace private var ns` in `HotelListingsView`) hosts every
matched identity. Single namespace = single morph graph; cross-cutting transitions
(card → detail, pill → overlay-pill) never collide because the IDs are distinct.

| Identity                       | Source                           | Destination                                          |
| ------------------------------ | -------------------------------- | ---------------------------------------------------- |
| `"searchPill"`                 | `searchPillBar` in browsing mode | Pill inside `SearchActiveOverlay`                    |
| `"card-\(section.id)-\(id)"`   | `CompactHotelCard` in carousel   | Hero region inside `HotelDetailScene`                |

The card source IDs are section-scoped (the same hotel can appear in "Top picks"
and "Best value" simultaneously). The host captures which card was tapped via the
`sourceID: String` field on `.detailExpanded`. The detail uses that exact string
as its hero's matched-geometry id.

## Where the search pill lives

Floating chrome, pinned via `.overlay(alignment: .top)` on the ZStack with safe-area
padding. It floats over the parallax hero photo, never scrolls away. Stable
geometry is mandatory for matched-geometry to morph cleanly — anchoring the pill
to a scroll position would jitter the morph.

The pill source identity is alive in browsing and detailExpanded states (so a
detail dismiss can still settle a pill morph if needed). It is unmounted in
searchActive — the overlay carries the matching identity.

## File boundaries

### Worker A — `Sources/Features/Search/SearchActiveOverlay.swift`
Owns the surface and morph behavior for Transition 1 (search-pill blur-crossfade).

- May freely edit `SearchActiveOverlay.swift`.
- May add private subviews / extensions inside that file.
- May read but **must not mutate** `HotelListingsView.swift` except to swap the
  `.transition(.opacity)` placeholder on the overlay mount with the appropriate
  `.transition(...)` (e.g. `.opacity` combined with the blur Worker A drives).
- May NOT modify `HotelDetailScene.swift`.
- Must wire the `matchedGeometryEffect(id: "searchPill", in: ns)` on its own pill
  so the morph animates between host pill and overlay pill.
- Delayed keyboard via `Task.sleep(for: .milliseconds(220))` then setting
  `@FocusState`. This `Task` lives in `SearchActiveOverlay`, NOT the view model.
- Tap-outside-pill dismiss: call `onDismiss()`. Animation envelope wraps the
  dismiss in `withAnimation(.easeInOut(duration: 0.2))`.

### Worker B — `Sources/Features/HotelDetail/HotelDetailScene.swift`
Owns the matched-geometry expansion (Transition 2).

- Owns: hero rendering, content layout, the hero's `matchedGeometryEffect(id:
  sourceID, in: ns)`, the 80–100ms content fade-in delay.
- May extend `HotelListingsView.swift` to:
  - Replace the `.transition(.opacity)` placeholder on the detail mount with the
    spring-driven matched-geometry transition.
  - Drive the explore-content blur/dim via the `dismissProgress` binding (already
    wired by the architect — Worker B just tunes the values).
- Must NOT add the drag gesture — that's Worker C's surface.
- Coordination: writes to the visual surface of `HotelDetailScene`. The
  `dismissProgress` binding is read-only for Worker B (Worker C is the writer).

### Worker C — `Sources/Features/HotelDetail/HotelDetailScene.swift`
Owns the swipe-down dismiss (Transition 3).

- May add per-frame `@State` (drag offset, throw velocity) to `HotelDetailScene`.
- Owns: `DragGesture` on the hero region (NOT the full scene — must not eat the
  ScrollView pan).
- Writes `dismissProgress` (the binding from the host) as the drag progresses
  past the rubber-band threshold.
- On commit (drag > 200pt OR predicted velocity > 600pt/s): calls `onDismiss()`.
- On release without commit: snaps `dragOffset` back to 0 with the spring from
  the brief.
- Hero parallax: `.frame(height: heroBaseHeight - max(0, dragOffset * 0.3))`.

### Both B and C — collision rules for `HotelDetailScene.swift`

- B owns the visual structure; C owns the gesture state.
- Conflict resolution: if B and C end up touching the same lines, they
  coordinate via SendMessage. Default precedence: whoever lands first wins; the
  other rebases.
- The function bodies at the boundary (`var body`) will likely be a small
  composition that pulls in B's content and C's gesture modifier. Keep that
  composition tight; both workers should stay within their own private extensions.

## Contract for `HotelDetailScene`

Architect-defined signature (B and C must respect this; new internals are fine):

```swift
struct HotelDetailScene: View {
    let hotel: Hotel
    let currency: Currency
    let ns: Namespace.ID
    let sourceID: String                      // matched-geom id of the source card
    @Binding var dismissProgress: CGFloat     // 0 = expanded, 1 = fully dismissed
    var onDismiss: () -> Void
}
```

`sourceID` is added beyond the brief's 5-parameter contract. The brief leaves the
matched-geometry threading implicit; `sourceID` makes it explicit and keeps
HotelDetailScene a closed unit (no peeking at section IDs through the host).
Workers B and C should treat this as authoritative.

## Contract for `SearchActiveOverlay`

```swift
struct SearchActiveOverlay: View {
    @Bindable var viewModel: SearchViewModel
    let ns: Namespace.ID
    var onDismiss: () -> Void
}
```

The host owns the `SearchViewModel` instance — Worker A reads/writes it but does
not own its lifetime.

## What the architect ships

1. This document.
2. Modified `HotelListingsView.swift`:
   - `@Namespace private var ns` (renamed from `heroNamespace`)
   - `@State private var presentation: PresentationLayer = .browsing`
   - `@State private var dismissProgress: CGFloat = 0`
   - `@State private var searchViewModel = SearchViewModel(client: .preview, logger: .silent)` — TODO: wire `.live()` in polish phase
   - ZStack composition described above
   - `searchPillBar` private view with `matchedGeometryEffect(id: "searchPill", in: ns)`
   - `.sheet(item:)` and `HotelDetailSheet` removed
3. New `Sources/Features/HotelDetail/HotelDetailScene.swift` — skeleton render of
   hero + content from the old `HotelDetailSheet`. No animation, no gesture.
4. New `Sources/Features/Search/SearchActiveOverlay.swift` — skeleton render of a
   search bar + content (delegates to `SearchViewModel`). No blur, no crossfade.

The build passes; the app behaviorally regresses to "tap card → detail crossfades
in; tap pill → overlay crossfades in" while the workers wire the morphs.

## Polish-phase TODOs (task #5)

- Wire `.live()` `SearchClient` into the host's `SearchViewModel` (probably by
  adding a `searchClient` parameter to `HotelListingsView` and passing it from
  `ResortPassApp`).
- Place selection inside `SearchActiveOverlay` — bubble up via a callback that
  pops the nav stack and pushes the new place's listings, OR replaces the path
  in one transaction.
- `accessibilityReduceMotion` fallbacks per the build brief.
- Kingfisher prefetch on press-down.
