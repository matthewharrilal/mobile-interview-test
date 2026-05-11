// Endpoints.swift
// Typed URL builders. Keeps URL string fragments out of Sources/.

import Foundation

enum Endpoints {
    /// Build the autocomplete URL for the staging API. Parameter labeled
    /// `matching:` to read as a phrase at the call site per Swift API
    /// Design Guidelines; the wire `terms` query name is unaffected.
    static func placesAutocomplete(matching terms: String, environment: APIEnvironment) -> URL {
        // Force-unwrap safety: appendingPathComponent always yields a valid
        // URL, and the literal staging base parses; URLComponents init
        // cannot fail from a known-good URL.
        var components = URLComponents(url: environment.baseURL.appendingPathComponent("/api/search/places/autocomplete"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "terms", value: terms),
            URLQueryItem(name: "limit", value: "\(Networking.Constants.autocompletePageSize)"),
            URLQueryItem(name: "offset", value: "0")
        ]
        // Force-unwrap safety: queryItems we set are all well-formed and
        // URL-encodable; components.url cannot return nil here.
        return components.url!
    }

    static func algoliaHotels(environment: APIEnvironment) -> URL {
        environment.baseURL.appendingPathComponent("/api/search/algolia_hotels_v7")
    }
}
