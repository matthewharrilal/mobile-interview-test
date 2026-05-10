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
