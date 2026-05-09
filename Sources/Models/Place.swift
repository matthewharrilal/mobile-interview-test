// Place.swift
// Cross-feature domain type — a searchable place returned by the autocomplete API.
// Coordinates may be nil for some real-world entries (e.g. Brooklyn, Florida).

import Foundation

struct Place: Equatable, Sendable, Hashable, Identifiable, Codable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let region: String?

    enum CodingKeys: String, CodingKey {
        case id = "place_id"
        case name
        case latitude
        case longitude
        case region
    }
}
