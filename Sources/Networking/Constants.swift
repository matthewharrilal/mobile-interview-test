// Constants.swift
// Numeric and string constants used by the networking layer.
// Centralised so a magic-number grep gate keeps Sources/ clean.

import Foundation

enum Networking {
    enum Constants {
        /// Debounce window before firing the autocomplete request after the latest keystroke.
        static let searchDebounce: Duration = .milliseconds(500)

        /// Page sizes per spec (autocomplete limit, hotel listings limit).
        static let autocompletePageSize = 10
        static let hotelsPageSize = 30

        /// Acceptable HTTP status range for a successful response.
        static let successStatusRange = 200..<300

        /// Default request timeout.
        static let requestTimeout: TimeInterval = 15

        /// Listings data is considered stale after this elapsed time when the
        /// app returns from background. On scene re-activation the listings
        /// VM checks `Date.now - fetchedAt` and dispatches a refresh if the
        /// threshold has been exceeded. 5 min balances "user backgrounded
        /// briefly to check a message" (no refetch) against "user came back
        /// hours later" (stale, refetch).
        static let listingsStaleThreshold: TimeInterval = 300
    }
}
