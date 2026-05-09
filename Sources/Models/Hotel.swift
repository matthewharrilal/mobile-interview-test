// Hotel.swift
// Cross-feature domain type — a hotel returned by the algolia_hotels_v7 API.
// Wire-level fields like queryID/objectID are stripped at the decode boundary.

import Foundation

struct Hotel: Equatable, Sendable, Hashable, Identifiable, Codable {
    let id: String
    let name: String
    let imageURL: URL?
    let rating: Double?
    let reviewCount: Int
    let distanceMiles: Double?
    let vibes: [String]
    let priceCents: Int
    let productName: String

    enum CodingKeys: String, CodingKey {
        case id = "objectID"
        case name
        case imageURL = "image_url"
        case rating
        case reviewCount = "review_count"
        case distanceMiles = "distance_miles"
        case vibes
        case priceCents = "price_cents"
        case productName = "product_name"
    }
}
