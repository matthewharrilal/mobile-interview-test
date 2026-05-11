// Hotel.swift
// Cross-feature domain type — a hotel returned by the algolia_hotels_v7 API.
// Maps the wire shape (desktop_img, rating, reviews, etc.) to a friendlier surface.

import Foundation

struct Hotel: Equatable, Sendable, Hashable, Identifiable, Codable {
    let id: Int
    let name: String
    let imageURL: URL?
    let imageURLs: [URL]
    let rating: Double?
    let reviewCount: Int
    let hotelStar: Int?
    let distanceMiles: Double?
    let distanceText: String?
    let cityName: String?
    let stateCode: String?
    let productName: String?
    let primaryVibe: String?
    let cheapestPrice: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case desktopImg = "desktop_img"
        case image
        case rating
        case reviews
        case hotelStar = "hotel_star"
        case distanceMiles = "distance_miles"
        case distanceText = "distance_text"
        case cityName = "city_name"
        case stateCode = "state_code"
        case productName = "product_name"
        case vibes
        case products
    }

    init(
        id: Int,
        name: String,
        imageURL: URL?,
        imageURLs: [URL] = [],
        rating: Double?,
        reviewCount: Int,
        hotelStar: Int? = nil,
        distanceMiles: Double?,
        distanceText: String?,
        cityName: String? = nil,
        stateCode: String? = nil,
        productName: String?,
        primaryVibe: String?,
        cheapestPrice: Double?
    ) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.imageURLs = imageURLs.isEmpty ? imageURL.map { [$0] } ?? [] : imageURLs
        self.rating = rating
        self.reviewCount = reviewCount
        self.hotelStar = hotelStar
        self.distanceMiles = distanceMiles
        self.distanceText = distanceText
        self.cityName = cityName
        self.stateCode = stateCode
        self.productName = productName
        self.primaryVibe = primaryVibe
        self.cheapestPrice = cheapestPrice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        let (primary, allImages) = try Self.decodeImageURLs(from: container)
        self.imageURL = primary
        self.imageURLs = allImages
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        self.reviewCount = (try? container.decode(Int.self, forKey: .reviews)) ?? 0
        self.hotelStar = try? container.decodeIfPresent(Int.self, forKey: .hotelStar)
        self.distanceMiles = try container.decodeIfPresent(Double.self, forKey: .distanceMiles)
        self.distanceText = try container.decodeIfPresent(String.self, forKey: .distanceText)
        self.cityName = try? container.decodeIfPresent(String.self, forKey: .cityName)
        self.stateCode = try? container.decodeIfPresent(String.self, forKey: .stateCode)
        self.productName = try container.decodeIfPresent(String.self, forKey: .productName)
        self.primaryVibe = Self.decodePrimaryVibe(from: container)
        self.cheapestPrice = Self.decodeCheapestPrice(from: container)
    }

    /// Pulls the primary image plus the deduplicated, ordered image list.
    /// `desktopImg` (a single string) is the primary; `image` is an array
    /// of nested `{picture:{url, results:{url}, details:{url}}}` records
    /// where the largest available URL per record is appended in order.
    private static func decodeImageURLs(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> (primary: URL?, all: [URL]) {
        let imgString = try container.decodeIfPresent(String.self, forKey: .desktopImg)
        let primary = imgString.flatMap { URL(string: $0) }
        var collected: [URL] = []
        if let primary { collected.append(primary) }
        let images = (try? container.decodeIfPresent([ImageWire].self, forKey: .image)) ?? []
        for img in images {
            // Prefer details URL (largest), fall back to results, then base url
            let candidates = [img.picture?.details?.url, img.picture?.results?.url, img.picture?.url]
                .compactMap { $0 }
            if let urlString = candidates.first,
               let url = URL(string: urlString),
               !collected.contains(url) {
                collected.append(url)
            }
        }
        return (primary, collected)
    }

    /// Reads `vibes.primary` defensively. `try?` everywhere so a missing
    /// container, null primary, or type-mismatched value all drop to nil
    /// without failing the whole hotel decode.
    private static func decodePrimaryVibe(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> String? {
        let vibesContainer = try? container.nestedContainer(keyedBy: VibesKeys.self, forKey: .vibes)
        return (try? vibesContainer?.decodeIfPresent(String.self, forKey: .primary)) ?? nil
    }

    /// Picks the minimum `price` across `products[]`. `try?` on the
    /// products decode so an object-shaped value (schema drift) yields
    /// nil instead of failing the hotel.
    private static func decodeCheapestPrice(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> Double? {
        let products = try? container.decodeIfPresent([Product].self, forKey: .products)
        return products?.compactMap(\.price).min()
    }

    /// Mirrors `init(from:)` so encode→decode round-trips preserve every field.
    /// Writes the wire shape (snake_case keys, nested `vibes`/`image`/`products`)
    /// not the in-memory shape, so the same `JSONDecoder` re-hydrates an equal Hotel.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(imageURL?.absoluteString, forKey: .desktopImg)
        if !imageURLs.isEmpty {
            let wireImages = imageURLs.map { ImageWire(picture: .init(url: $0.absoluteString, results: nil, details: nil)) }
            try container.encode(wireImages, forKey: .image)
        }
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encode(reviewCount, forKey: .reviews)
        try container.encodeIfPresent(hotelStar, forKey: .hotelStar)
        try container.encodeIfPresent(distanceMiles, forKey: .distanceMiles)
        try container.encodeIfPresent(distanceText, forKey: .distanceText)
        try container.encodeIfPresent(cityName, forKey: .cityName)
        try container.encodeIfPresent(stateCode, forKey: .stateCode)
        try container.encodeIfPresent(productName, forKey: .productName)
        if primaryVibe != nil {
            var vibesContainer = container.nestedContainer(keyedBy: VibesKeys.self, forKey: .vibes)
            try vibesContainer.encodeIfPresent(primaryVibe, forKey: .primary)
        }
        if let cheapestPrice {
            // Decoder derives cheapestPrice as min(products[].price); encode a
            // single product so the round-trip yields the same minimum.
            try container.encode([Product(price: cheapestPrice)], forKey: .products)
        }
    }

    /// Display location: "Costa Mesa, CA" or just city if state unknown.
    var displayLocation: String? {
        switch (cityName, stateCode) {
        case let (city?, state?) where !city.isEmpty && !state.isEmpty:
            return "\(city), \(state)"
        case let (city?, _) where !city.isEmpty:
            return city
        default:
            return nil
        }
    }

    /// One-line editorial tagline composed from available fields. Used in
    /// place of the metadata strip on editorial cards. Mirrors the Mr & Mrs
    /// Smith "single italic editorial sentence" pattern.
    var editorialTagline: String {
        let vibePart: String? = primaryVibe.map { $0.lowercased() }
        let starPart: String? = hotelStar.map { stars in
            switch stars {
            case 5: return "five-star"
            case 4: return "four-star"
            case 3: return "three-star"
            default: return nil
            }
        } ?? nil
        let descriptor = [starPart, vibePart].compactMap { $0 }.first
        switch (descriptor, cityName) {
        case let (desc?, city?) where !city.isEmpty:
            return "A \(desc) escape in \(city)."
        case let (desc?, _):
            return "A \(desc) escape."
        case let (_, city?) where !city.isEmpty:
            return "A day pass in \(city)."
        default:
            return "A day pass."
        }
    }

    private enum VibesKeys: String, CodingKey {
        case primary
        case secondary
    }

    private struct Product: Codable {
        let price: Double?
    }

    private struct ImageWire: Codable {
        let picture: PictureWire?

        struct PictureWire: Codable {
            let url: String?
            let results: SizedURL?
            let details: SizedURL?
        }

        struct SizedURL: Codable {
            let url: String?
        }
    }
}
