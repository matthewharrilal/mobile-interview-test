// Endpoints.swift
// Typed URL builders. Keeps URL string fragments out of Sources/.

import Foundation

enum Endpoints {
    static func placesAutocomplete(terms: String, environment: APIEnvironment) -> URL {
        var components = URLComponents(url: environment.baseURL.appendingPathComponent("/api/search/places/autocomplete"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "terms", value: terms),
            URLQueryItem(name: "limit", value: "\(Networking.Constants.autocompletePageSize)"),
            URLQueryItem(name: "offset", value: "0")
        ]
        return components.url!
    }

    static func algoliaHotels(environment: APIEnvironment) -> URL {
        environment.baseURL.appendingPathComponent("/api/search/algolia_hotels_v7")
    }
}
