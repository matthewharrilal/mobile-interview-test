// Strings.swift
// User-facing copy and accessibility labels in one place.
// Wrap every value in String(localized:) so swapping in .strings tables later
// requires no source changes — only adding the keys to Localizable.xcstrings.

import Foundation

enum Strings {

    // MARK: - Search screen

    enum Search {
        static let navTitle = String(localized: "search.navTitle", defaultValue: "Day Passes")
        static let placeholder = String(localized: "search.placeholder", defaultValue: "Search cities, hotels…")
        static let idleHeadline = String(localized: "search.idle.headline", defaultValue: "Where are you headed?")
        static let idleSubtitle = String(localized: "search.idle.subtitle", defaultValue: "Type a city, neighborhood, or hotel\nname to discover day passes.")
        static let emptyHeadline = String(localized: "search.empty.headline", defaultValue: "No places found")
        static let emptyDescriptionFormat = String(localized: "search.empty.description", defaultValue: "We couldn't find anywhere matching \u{201C}%@\u{201D}. Try another term.")
        static let failedHeadline = String(localized: "search.failed.headline", defaultValue: "Couldn't search")
        static let failedNetwork = String(localized: "search.failed.network", defaultValue: "You appear to be offline. Reconnect and try again.")
        static let failedTimeout = String(localized: "search.failed.timeout", defaultValue: "The search took too long. Try again in a moment.")
        static let failedServer = String(localized: "search.failed.server", defaultValue: "Our servers are having trouble. Please try again shortly.")
        static let failedDecode = String(localized: "search.failed.decode", defaultValue: "We received an unexpected response. Please try again.")
        static let failedUnknown = String(localized: "search.failed.unknown", defaultValue: "Something went wrong. Check your connection and try again.")
        static let nullCoordsFormat = String(localized: "search.failed.nullCoords", defaultValue: "We don't have coordinates for %@ yet. Try a nearby city.")
        static let nullCoordsHeadline = String(localized: "search.failed.nullCoords.headline", defaultValue: "Coordinates unavailable")
        static let nullCoordsCTA = String(localized: "search.failed.nullCoords.cta", defaultValue: "Search a nearby city")
        static let tryAgain = String(localized: "common.tryAgain", defaultValue: "Try Again")
    }

    // MARK: - Hotel listings screen

    enum Hotels {
        static let emptyHeadline = String(localized: "hotels.empty.headline", defaultValue: "No hotels available")
        static let emptyDescriptionFormat = String(localized: "hotels.empty.description", defaultValue: "We couldn't find any day passes near %@.")
        static let backToSearch = String(localized: "hotels.empty.backToSearch", defaultValue: "Back to Search")
        static let failedHeadline = String(localized: "hotels.failed.headline", defaultValue: "Couldn't load hotels")
        static let failedNetwork = String(localized: "hotels.failed.network", defaultValue: "You appear to be offline. Reconnect and try again.")
        static let failedTimeout = String(localized: "hotels.failed.timeout", defaultValue: "Loading hotels took too long. Try again in a moment.")
        static let failedServer = String(localized: "hotels.failed.server", defaultValue: "Our servers are having trouble. Please try again shortly.")
        static let failedDecode = String(localized: "hotels.failed.decode", defaultValue: "We received an unexpected response. Please try again.")
        static let failedUnknown = String(localized: "hotels.failed.unknown", defaultValue: "Something went wrong. Check your connection and try again.")
    }

    // MARK: - Accessibility

    enum Accessibility {
        static let searchField = String(localized: "a11y.searchField", defaultValue: "Search field. Type a city, neighborhood, or hotel name.")
        static let clearSearch = String(localized: "a11y.clearSearch", defaultValue: "Clear search")
        static let placeRowHintFormat = String(localized: "a11y.placeRowHint", defaultValue: "View hotels near %@")
        static func hotelRowLabel(name: String, rating: Double?, distance: String?, price: String?) -> String {
            var parts = [name]
            if let rating { parts.append(String(localized: "a11y.rating.format", defaultValue: "rated \(rating, format: .number.precision(.fractionLength(1))) out of 5")) }
            if let distance { parts.append(distance) }
            if let price { parts.append(price) }
            return parts.joined(separator: ", ")
        }
    }
}
