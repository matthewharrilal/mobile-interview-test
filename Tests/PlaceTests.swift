// PlaceTests.swift
// Verifies Place decoding against real staging-app responses + null-coord guard.

import XCTest
@testable import ResortPass

final class PlaceTests: XCTestCase {

    // MARK: - Decoding

    func test_decode_realNewportResponse_yieldsExpectedPlaces() throws {
        let data = try fixture("places-newport")
        let places = try Decoders.api.decode([Place].self, from: data)

        XCTAssertGreaterThanOrEqual(places.count, 5, "Newport search should return multiple places")
        let names = places.map(\.name)
        XCTAssertTrue(names.contains("Newport Beach, California"))
        XCTAssertTrue(names.contains("Newport, Rhode Island"))
    }

    func test_decode_brooklynResponse_includesNullCoordPlace() throws {
        let data = try fixture("places-brooklyn")
        let places = try Decoders.api.decode([Place].self, from: data)

        // The real API returns "Brooklyn, Florida" with latitude=null, longitude=null.
        // The decoder must NOT crash on this; the guard runs at the View layer.
        let brooklynFL = places.first { $0.name == "Brooklyn, Florida" }
        XCTAssertNotNil(brooklynFL, "Brooklyn FL must decode (the canonical null-coord case)")
        XCTAssertNil(brooklynFL?.latitude, "Brooklyn FL latitude is null in the real API")
        XCTAssertNil(brooklynFL?.longitude, "Brooklyn FL longitude is null in the real API")
        XCTAssertFalse(brooklynFL?.hasUsableCoordinates ?? true, "hasUsableCoordinates must be false")
    }

    func test_decode_handlesIdCollision_viaObjectIdIdentity() throws {
        // Newport Beach (id=236) and Newport Coast (id=236) share an integer id.
        // Identifiable.id maps to objectID (string), which IS unique.
        let data = try fixture("places-newport")
        let places = try Decoders.api.decode([Place].self, from: data)

        let beach = places.first { $0.name == "Newport Beach, California" }
        let coast = places.first { $0.name == "Newport Coast, California" }
        XCTAssertNotNil(beach)
        XCTAssertNotNil(coast)
        XCTAssertEqual(beach?.placeID, coast?.placeID, "API id collision is real")
        XCTAssertNotEqual(beach?.id, coast?.id, "Identifiable.id (objectID) must distinguish them")
    }

    // MARK: - Defensive decoding (FailableDecodable)

    func test_decodeLossy_dropsMalformedRows_preservesGoodRows() throws {
        // Mixed array: one valid Place, one row missing required `objectID`,
        // one row with `id` as a String. Lossy decode should drop the bad
        // two and return only the valid Place.
        let json = """
        [
          { "id": 1, "objectID": "valid", "name": "Valid Place", "type": "city",
            "city_name": "Valid", "state_code": "CA", "country_code": "US",
            "latitude": 33.0, "longitude": -117.0 },
          { "id": 2, "name": "Missing ObjectID", "type": "city",
            "city_name": "X", "state_code": "CA", "country_code": "US",
            "latitude": 33.0, "longitude": -117.0 },
          { "id": "three-as-string", "objectID": "type-mismatch", "name": "Bad ID Type",
            "type": "city", "city_name": "X", "state_code": "CA", "country_code": "US",
            "latitude": 33.0, "longitude": -117.0 }
        ]
        """.data(using: .utf8)!

        let places = try Decoders.api.decodeLossy([Place].self, from: json)
        XCTAssertEqual(places.count, 1, "Only the valid row should survive lossy decode")
        XCTAssertEqual(places.first?.objectID, "valid")
    }

    func test_decodeLossy_emptyArray_returnsEmpty() throws {
        let json = "[]".data(using: .utf8)!
        let places = try Decoders.api.decodeLossy([Place].self, from: json)
        XCTAssertTrue(places.isEmpty)
    }

    func test_decodeLossy_allRowsValid_returnsAll() throws {
        let json = """
        [
          { "id": 1, "objectID": "a", "name": "A", "type": "city",
            "city_name": "A", "state_code": "CA", "country_code": "US",
            "latitude": 0, "longitude": 0 },
          { "id": 2, "objectID": "b", "name": "B", "type": "city",
            "city_name": "B", "state_code": "CA", "country_code": "US",
            "latitude": 0, "longitude": 0 }
        ]
        """.data(using: .utf8)!
        let places = try Decoders.api.decodeLossy([Place].self, from: json)
        XCTAssertEqual(places.count, 2)
    }

    func test_decodeLossy_allRowsMalformed_returnsEmpty() throws {
        // Per the contract: lossy decode of an all-malformed array returns
        // empty (not throws). The VM will then surface this as `.empty` —
        // which is the correct user-facing message ("no results for your
        // query") given the data shape is irrecoverable.
        let json = """
        [
          { "garbage": true },
          { "id": "string", "objectID": "x" }
        ]
        """.data(using: .utf8)!
        let places = try Decoders.api.decodeLossy([Place].self, from: json)
        XCTAssertTrue(places.isEmpty, "All malformed → empty array (not throw)")
    }

    // MARK: - Adversarial Hotel decoding

    func test_decode_hotelWithIdAsString_throwsDecodingError() throws {
        // Hotel.id is non-optional Int. Per audit-A's documented decode
        // trade-off, optional `decodeIfPresent` fields (hotelStar,
        // cityName, etc) use `try?` so partial drift is silently nilled —
        // but `id` is REQUIRED and must throw `DecodingError.typeMismatch`
        // so the VM surfaces `.failed(decodeError)`.
        let json = """
        { "id": "not-an-int", "name": "X" }
        """.data(using: .utf8)!
        do {
            _ = try Decoders.api.decode(Hotel.self, from: json)
            XCTFail("Expected DecodingError.typeMismatch for id-as-string")
        } catch is DecodingError {
            // success — required field type mismatch surfaces the error path
        } catch {
            XCTFail("Expected DecodingError, got \(type(of: error)): \(error)")
        }
    }

    func test_decode_hotelWithMissingName_throwsDecodingError() throws {
        // Same: name is required. Missing it must throw.
        let json = """
        { "id": 1 }
        """.data(using: .utf8)!
        do {
            _ = try Decoders.api.decode(Hotel.self, from: json)
            XCTFail("Expected DecodingError.keyNotFound for missing name")
        } catch is DecodingError {
            // success
        } catch {
            XCTFail("Expected DecodingError, got \(error)")
        }
    }

    func test_decode_hotelWithVibesAsNull_silentlyNilled() throws {
        // vibes is decoded via `try?` per the documented trade-off — null
        // is acceptable. The hotel decodes successfully with `primaryVibe = nil`.
        let json = """
        { "id": 1, "name": "Test Hotel", "vibes": null }
        """.data(using: .utf8)!
        let hotel = try Decoders.api.decode(Hotel.self, from: json)
        XCTAssertEqual(hotel.id, 1)
        XCTAssertEqual(hotel.name, "Test Hotel")
        XCTAssertNil(hotel.primaryVibe, "Null vibes must decode to nil, not throw")
    }

    func test_decode_hotelWithHotelStarAsString_silentlyNilled() throws {
        // hotelStar is decoded via `try?` per the documented trade-off.
        // A type-mismatched value drops to nil rather than failing the whole
        // hotel decode.
        let json = """
        { "id": 1, "name": "Test", "hotel_star": "four-stars" }
        """.data(using: .utf8)!
        let hotel = try Decoders.api.decode(Hotel.self, from: json)
        XCTAssertEqual(hotel.id, 1)
        XCTAssertNil(hotel.hotelStar, "String for hotel_star must decode to nil via try?")
    }

    func test_decode_hotelWithProductsAsObject_silentlyDropsProducts() throws {
        // products is `[Product]?` decoded via `try?`. Schema drift where
        // the API returns an object instead of an array must drop the
        // products silently (rather than nuke the whole hotel).
        let json = """
        { "id": 1, "name": "Test", "products": { "id": 5, "price": 50.0 } }
        """.data(using: .utf8)!
        let hotel = try Decoders.api.decode(Hotel.self, from: json)
        XCTAssertEqual(hotel.id, 1)
        XCTAssertNil(hotel.cheapestPrice, "Object-shaped products silently dropped → no cheapestPrice")
    }

    func test_decode_hotelsArrayWithOneMalformedRow_keepsRest() throws {
        // The HotelsClient response uses FailableDecodable<Hotel> on the
        // hotels array — one malformed row should NOT drop the rest. Pin
        // via direct wire decode using the same wire path the client uses.
        let json = """
        {
          "hotels": [
            { "id": 1, "name": "Valid Hotel" },
            { "id": "bad", "name": "Bad Hotel" },
            { "id": 3, "name": "Another Valid Hotel" }
          ],
          "currency": { "symbol": "$", "iso_code": "USD" },
          "total": 3
        }
        """.data(using: .utf8)!
        struct WireResponse: Decodable {
            let hotels: [Hotel]
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let wrapped = try container.decode([FailableDecodable<Hotel>].self, forKey: .hotels)
                self.hotels = wrapped.compactMap(\.value)
            }
            enum CodingKeys: String, CodingKey { case hotels }
        }
        let response = try Decoders.api.decode(WireResponse.self, from: json)
        XCTAssertEqual(response.hotels.count, 2, "One bad row drops; the other two survive")
        XCTAssertEqual(response.hotels.map(\.id).sorted(), [1, 3])
    }

    // MARK: - Display

    func test_displayRegion_city_combinesCityStateCountry() {
        let p = Place(placeID: 1, objectID: "x", name: "X", type: "city",
                      cityName: "Jersey City", stateCode: "NJ", countryCode: "US",
                      latitude: 0, longitude: 0)
        XCTAssertEqual(p.displayRegion, "Jersey City · NJ, US")
    }

    func test_displayRegion_country_marksAsCountry() {
        let p = Place(placeID: 14, objectID: "Jamaica", name: "Jamaica", type: "country",
                      cityName: "", stateCode: "", countryCode: "JM",
                      latitude: 18.1, longitude: -77.3)
        XCTAssertEqual(p.displayRegion, "JM · Country")
    }

    // MARK: - Helpers

    private func fixture(_ name: String) throws -> Data {
        let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: "json")
            ?? URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/\(name).json")
        return try Data(contentsOf: url)
    }
}
