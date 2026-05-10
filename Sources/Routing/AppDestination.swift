// AppDestination.swift
// The single value-based destination type used by NavigationStack(path:).
// Add a case here whenever a new push-able screen ships.

import Foundation

enum AppDestination: Hashable, Sendable {
    case hotelListings(place: Place)
    /// iOS 18+ push-based detail. Pushed by HotelListingsView's card tap when
    /// `.matchedTransitionSource` + `.navigationTransition(.zoom)` is available.
    /// On iOS 17, the existing ZStack-overlay path inside HotelListingsView
    /// remains in use and this case is never produced.
    case hotelDetail(hotel: Hotel, sourceID: String, currency: Currency)
}
