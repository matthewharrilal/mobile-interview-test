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
        let imgString = try container.decodeIfPresent(String.self, forKey: .desktopImg)
        let primary = imgString.flatMap { URL(string: $0) }
        self.imageURL = primary

        // image[] is an array of nested {picture:{url, results:{url}, details:{url}}}
        let images = (try? container.decodeIfPresent([ImageWire].self, forKey: .image)) ?? []
        var collected: [URL] = []
        if let primary { collected.append(primary) }
        for img in images {
            // Prefer details URL (largest), fall back to results, then base url
            let candidates = [img.picture?.details?.url, img.picture?.results?.url, img.picture?.url]
                .compactMap { $0 }
            if let urlString = candidates.first, let url = URL(string: urlString), !collected.contains(url) {
                collected.append(url)
            }
        }
        self.imageURLs = collected

        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        self.reviewCount = (try? container.decode(Int.self, forKey: .reviews)) ?? 0
        self.hotelStar = try? container.decodeIfPresent(Int.self, forKey: .hotelStar)
        self.distanceMiles = try container.decodeIfPresent(Double.self, forKey: .distanceMiles)
        self.distanceText = try container.decodeIfPresent(String.self, forKey: .distanceText)
        self.cityName = try? container.decodeIfPresent(String.self, forKey: .cityName)
        self.stateCode = try? container.decodeIfPresent(String.self, forKey: .stateCode)
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

    private enum VibesKeys: String, CodingKey {
        case primary
        case secondary
    }

    private struct Product: Decodable {
        let price: Double?
    }

    private struct ImageWire: Decodable {
        let picture: PictureWire?

        struct PictureWire: Decodable {
            let url: String?
            let results: SizedURL?
            let details: SizedURL?
        }

        struct SizedURL: Decodable {
            let url: String?
        }
    }
}
