// Hotel.swift
// Cross-feature domain type — a hotel returned by the algolia_hotels_v7 API.
// Maps the wire shape (desktop_img, rating, reviews, etc.) to a friendlier surface.

import Foundation

struct Hotel: Equatable, Sendable, Hashable, Identifiable, Codable {
    let id: Int
    let name: String
    let imageURL: URL?
    let rating: Double?
    let reviewCount: Int
    let distanceMiles: Double?
    let distanceText: String?
    let productName: String?
    let primaryVibe: String?
    let cheapestPrice: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case desktopImg = "desktop_img"
        case rating
        case reviews
        case distanceMiles = "distance_miles"
        case distanceText = "distance_text"
        case productName = "product_name"
        case vibes
        case products
    }

    init(
        id: Int,
        name: String,
        imageURL: URL?,
        rating: Double?,
        reviewCount: Int,
        distanceMiles: Double?,
        distanceText: String?,
        productName: String?,
        primaryVibe: String?,
        cheapestPrice: Double?
    ) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.rating = rating
        self.reviewCount = reviewCount
        self.distanceMiles = distanceMiles
        self.distanceText = distanceText
        self.productName = productName
        self.primaryVibe = primaryVibe
        self.cheapestPrice = cheapestPrice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        let imgString = try container.decodeIfPresent(String.self, forKey: .desktopImg)
        self.imageURL = imgString.flatMap { URL(string: $0) }
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        self.reviewCount = (try? container.decode(Int.self, forKey: .reviews)) ?? 0
        self.distanceMiles = try container.decodeIfPresent(Double.self, forKey: .distanceMiles)
        self.distanceText = try container.decodeIfPresent(String.self, forKey: .distanceText)
        self.productName = try container.decodeIfPresent(String.self, forKey: .productName)
        let vibesContainer = try? container.nestedContainer(keyedBy: VibesKeys.self, forKey: .vibes)
        self.primaryVibe = try? vibesContainer?.decodeIfPresent(String.self, forKey: .primary)
        let products = try? container.decodeIfPresent([Product].self, forKey: .products)
        self.cheapestPrice = products?.compactMap(\.price).min()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }

    private enum VibesKeys: String, CodingKey {
        case primary
        case secondary
    }

    private struct Product: Decodable {
        let price: Double?
    }
}
