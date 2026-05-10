// HotelTests.swift
// Verifies the custom Hotel decoder against the real algolia_hotels_v7 response.
// Real API quirks covered: nested image objects, vibes object, products array
// with min(price), `rating` (not `avg_rating`).

import XCTest
@testable import ResortPass

final class HotelTests: XCTestCase {

    func test_decode_realHotelsResponse_yieldsHotelsAndCurrency() throws {
        let data = try fixture("hotels-newport")
        let response = try Decoders.api.decode(WireResponse.self, from: data)
        XCTAssertGreaterThan(response.hotels.count, 0)
        XCTAssertEqual(response.currency?.iso_code ?? "USD", "USD")
    }

    func test_hotel_pickRatingFieldNotAvgRating() throws {
        // The API exposes both `rating` (human-friendly, e.g. 4.4) and
        // `avg_rating` (often 0.0 — internal field). The model must use `rating`.
        let json = """
        { "id": 1, "name": "X", "rating": 4.4, "avg_rating": 0.0,
          "reviews": 10, "distance_miles": 5,
          "vibes": { "primary": "Trendy", "secondary": null },
          "products": [{ "price": 50.0 }],
          "product_name": "Day Pass" }
        """.data(using: .utf8)!
        let hotel = try Decoders.api.decode(Hotel.self, from: json)
        XCTAssertEqual(hotel.rating, 4.4)
        XCTAssertEqual(hotel.reviewCount, 10)
        XCTAssertEqual(hotel.primaryVibe, "Trendy")
        XCTAssertEqual(hotel.cheapestPrice, 50)
        XCTAssertEqual(hotel.productName, "Day Pass")
    }

    func test_hotel_handlesMissingOptionalFields() throws {
        // API can omit rating, distance, products. Decoder must not throw.
        let json = """
        { "id": 2, "name": "Minimal Hotel" }
        """.data(using: .utf8)!
        let hotel = try Decoders.api.decode(Hotel.self, from: json)
        XCTAssertEqual(hotel.id, 2)
        XCTAssertEqual(hotel.name, "Minimal Hotel")
        XCTAssertNil(hotel.rating)
        XCTAssertEqual(hotel.reviewCount, 0)
        XCTAssertNil(hotel.cheapestPrice)
    }

    func test_hotel_cheapestPrice_picksMinimumAcrossProducts() throws {
        let json = """
        { "id": 3, "name": "Multi Product",
          "products": [
            { "price": 120.0 }, { "price": 75.0 }, { "price": 200.0 }
          ]
        }
        """.data(using: .utf8)!
        let hotel = try Decoders.api.decode(Hotel.self, from: json)
        XCTAssertEqual(hotel.cheapestPrice, 75)
    }

    func test_hotel_encodeDecode_roundTripPreservesAllFields() throws {
        // Round-trip via JSONEncoder → JSONDecoder must reconstruct an equal Hotel.
        // Guards against the previous asymmetric encode that wrote only id+name.
        let original = Hotel(
            id: 42,
            name: "The Round Trip Resort",
            imageURL: URL(string: "https://cdn.example.com/primary.jpg"),
            imageURLs: [
                URL(string: "https://cdn.example.com/primary.jpg")!,
                URL(string: "https://cdn.example.com/extra1.jpg")!,
                URL(string: "https://cdn.example.com/extra2.jpg")!
            ],
            rating: 4.6,
            reviewCount: 318,
            hotelStar: 5,
            distanceMiles: 12.4,
            distanceText: "12 mi",
            cityName: "Newport Beach",
            stateCode: "CA",
            productName: "Cabana Day Pass",
            primaryVibe: "Coastal",
            cheapestPrice: 89.5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let restored = try Decoders.api.decode(Hotel.self, from: data)

        XCTAssertEqual(restored, original)
    }

    func test_hotel_encodeDecode_roundTripWithMinimalFields() throws {
        // Only id + name set; optionals nil; imageURLs empty. Must still round-trip.
        let original = Hotel(
            id: 7,
            name: "Bare",
            imageURL: nil,
            imageURLs: [],
            rating: nil,
            reviewCount: 0,
            hotelStar: nil,
            distanceMiles: nil,
            distanceText: nil,
            cityName: nil,
            stateCode: nil,
            productName: nil,
            primaryVibe: nil,
            cheapestPrice: nil
        )

        let data = try JSONEncoder().encode(original)
        let restored = try Decoders.api.decode(Hotel.self, from: data)

        XCTAssertEqual(restored, original)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: "json")
            ?? URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/\(name).json")
        return try Data(contentsOf: url)
    }

    private struct WireResponse: Decodable {
        let hotels: [Hotel]
        let currency: CurrencyWire?
        struct CurrencyWire: Decodable { let iso_code: String? }
    }
}
