// AppDestination.swift
// The single value-based destination type used by NavigationStack(path:).
// Add a case here whenever a new push-able screen ships.

import Foundation

enum AppDestination: Hashable, Sendable {
    case hotelListings(place: Place)
    /// **OS-version-specific.** This case is ONLY produced on iOS 18+ where
    /// `.matchedTransitionSource` + `.navigationTransition(.zoom)` are
    /// available — `HotelListingsView` pushes this onto `state.path` and
    /// `RootNavigationView.navigationDestination` resolves it to a
    /// `HotelDetailScene` in `.pushed` mode.
    ///
    /// On iOS 17, the detail screen lives in `HotelListingsState.PresentationLayer.detailExpanded(...)` — a
    /// ZStack overlay inside `HotelListingsView` driven by a matched-geometry
    /// morph. The path is NEVER mutated with `.hotelDetail` on iOS 17, so
    /// this case is *dead code* on the lower-bound deployment.
    ///
    /// `sourceID` is an animation-coordination identifier (the
    /// matchedTransitionSource id paired with the destination's
    /// `.navigationTransition(.zoom(sourceID:in:))`). It IS a routing
    /// concern only because the zoom API requires the source + destination
    /// to share an id in the same `Namespace`. A future refactor could
    /// compute it at the destination from `hotel.id` and drop it from the
    /// routing payload — see audit-C §Navigation gap #9.
    case hotelDetail(hotel: Hotel, sourceID: String, currency: Currency)
}
