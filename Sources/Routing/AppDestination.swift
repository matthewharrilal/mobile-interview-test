// AppDestination.swift
// The single value-based destination type used by NavigationStack(path:).
// Add a case here whenever a new push-able screen ships.

import Foundation

enum AppDestination: Hashable, Sendable {
    case hotelListings(place: Place)
}
