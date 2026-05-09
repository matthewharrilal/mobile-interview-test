// Strings.swift
// User-facing copy and accessibility labels in one place.
// Wrap every value in String(localized:) so swapping in .strings tables later
// requires no source changes — only adding the keys to Localizable.xcstrings.

import Foundation

enum Strings {

    // MARK: - Search screen

    enum Search {
        static let navTitle = String(localized: "search.navTitle", defaultValue: "Pokédex")
        static let placeholder = String(localized: "search.placeholder", defaultValue: "Search cities, hotels…")
        static let idleHeadline = String(localized: "search.idle.headline", defaultValue: "Where are you headed?")
        static let idleSubtitle = String(localized: "search.idle.subtitle", defaultValue: "Type a city, neighborhood, or hotel\nname to discover day passes.")
        static let emptyHeadline = String(localized: "search.empty.headline", defaultValue: "No places found")
        static let emptyDescriptionFormat = String(localized: "search.empty.description", defaultValue: "We couldn't find anywhere matching \u{201C}%@\u{201D}. Try another term.")
        static let failedHeadline = String(localized: "search.failed.headline", defaultValue: "Couldn't search")
        static let failedNetwork = String(localized: "search.failed.network", defaultValue: "We couldn't reach our servers. Check your connection and try again.")
        static let nullCoordsFormat = String(localized: "search.failed.nullCoords", defaultValue: "We don't have coordinates for %@ yet. Try a nearby city.")
        static let tryAgain = String(localized: "common.tryAgain", defaultValue: "Try Again")
    }

    // MARK: - Hotel listings screen

    enum Hotels {
        static let emptyHeadline = String(localized: "hotels.empty.headline", defaultValue: "No hotels available")
        static let emptyDescriptionFormat = String(localized: "hotels.empty.description", defaultValue: "We couldn't find any day passes near %@.")
        static let backToSearch = String(localized: "hotels.empty.backToSearch", defaultValue: "Back to Search")
        static let failedHeadline = String(localized: "hotels.failed.headline", defaultValue: "Couldn't load hotels")
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
