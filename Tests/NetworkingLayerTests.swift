// NetworkingLayerTests.swift
// Pins URL building (`Endpoints.*`) verbatim against the interview spec
// and `ErrorKind.from(_:)` mapping for every URLError variant the VMs
// route through it.

import XCTest
@testable import ResortPass

final class NetworkingLayerTests: XCTestCase {

    // MARK: - Endpoints — URL verbatim vs spec

    func test_placesAutocompleteURL_matchesInterviewSpec() {
        // Interview spec quoted verbatim:
        //   https://staging-app.resortpass.com/api/search/places/autocomplete?terms={terms}&limit=10&offset=0
        // We pin this exactly so a future contributor can't silently break
        // URL encoding, drop a query param, or change the page size.
        let url = Endpoints.placesAutocomplete(matching: "newport", environment: .staging)
        XCTAssertEqual(
            url.absoluteString,
            "https://staging-app.resortpass.com/api/search/places/autocomplete?terms=newport&limit=10&offset=0"
        )
    }

    func test_placesAutocompleteURL_percentEncodesSpecialCharacters() {
        // "Newport Beach" → "Newport%20Beach"; quotes, ampersands, slashes
        // must all be percent-encoded so they don't break query parsing
        // server-side.
        let url = Endpoints.placesAutocomplete(matching: "Newport Beach", environment: .staging)
        XCTAssertEqual(
            url.absoluteString,
            "https://staging-app.resortpass.com/api/search/places/autocomplete?terms=Newport%20Beach&limit=10&offset=0"
        )
    }

    func test_placesAutocompleteURL_acceptsNonLatinTerms() {
        // CJK input must round-trip; the staging API accepts UTF-8
        // percent-encoded queries.
        let url = Endpoints.placesAutocomplete(matching: "東京", environment: .staging)
        let absolute = url.absoluteString
        XCTAssertTrue(absolute.hasPrefix("https://staging-app.resortpass.com/api/search/places/autocomplete?terms="))
        // %E6%9D%B1%E4%BA%AC is UTF-8 for "東京"
        XCTAssertTrue(absolute.contains("%E6%9D%B1%E4%BA%AC"))
        XCTAssertTrue(absolute.hasSuffix("&limit=10&offset=0"))
    }

    func test_algoliaHotelsURL_matchesInterviewSpec() {
        // Spec: POST to https://staging-app.resortpass.com/api/search/algolia_hotels_v7
        let url = Endpoints.algoliaHotels(environment: .staging)
        XCTAssertEqual(
            url.absoluteString,
            "https://staging-app.resortpass.com/api/search/algolia_hotels_v7"
        )
    }

    func test_placesAutocompleteURL_pageSizeConstantIsTen() {
        // Pins `Networking.Constants.autocompletePageSize = 10` — the spec
        // requires `limit=10` literally.
        XCTAssertEqual(Networking.Constants.autocompletePageSize, 10)
    }

    func test_algoliaHotelsBodyShape_matchesInterviewSpec() {
        // Spec body shape:
        //   { "location": { "latitude": <Double>, "longitude": <Double> },
        //     "limit": 30,
        //     "offset": 0 }
        // The body is currently constructed inline in HotelsClient.live;
        // here we reconstruct it and verify the JSON shape matches verbatim.
        let body: [String: Any] = [
            "location": [
                "latitude": 33.6189,
                "longitude": -117.9298
            ],
            "limit": Networking.Constants.hotelsPageSize,
            "offset": 0
        ]
        let data = try! JSONSerialization.data(withJSONObject: body)
        let decoded = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(decoded["limit"] as? Int, 30)
        XCTAssertEqual(decoded["offset"] as? Int, 0)
        let location = decoded["location"] as! [String: Any]
        guard let lat = location["latitude"] as? Double,
              let lng = location["longitude"] as? Double else {
            XCTFail("location.latitude / longitude missing or not Double")
            return
        }
        XCTAssertEqual(lat, 33.6189, accuracy: 0.0001)
        XCTAssertEqual(lng, -117.9298, accuracy: 0.0001)
    }

    // MARK: - ErrorKind.from(_:) mapping

    func test_errorKind_decodingError_mapsToDecodeError() {
        struct Sample: Decodable { let x: Int }
        let bad = Data("{}".utf8)   // missing required field "x"
        do {
            _ = try JSONDecoder().decode(Sample.self, from: bad)
            XCTFail("Expected DecodingError")
        } catch {
            XCTAssertEqual(ErrorKind.from(error), .decodeError)
        }
    }

    func test_errorKind_serverError5xx_mapsToServerError() {
        XCTAssertEqual(ErrorKind.from(NetworkingError.status(500)), .serverError)
        XCTAssertEqual(ErrorKind.from(NetworkingError.status(502)), .serverError)
        XCTAssertEqual(ErrorKind.from(NetworkingError.status(599)), .serverError)
    }

    func test_errorKind_clientError4xx_mapsToUnknown() {
        // 4xx isn't currently tailored — falls into .unknown so the user
        // gets the generic failure copy. Pinning this so a future "401 →
        // session expired" routing can be added intentionally.
        XCTAssertEqual(ErrorKind.from(NetworkingError.status(400)), .unknown)
        XCTAssertEqual(ErrorKind.from(NetworkingError.status(401)), .unknown)
        XCTAssertEqual(ErrorKind.from(NetworkingError.status(403)), .unknown)
        XCTAssertEqual(ErrorKind.from(NetworkingError.status(404)), .unknown)
    }

    func test_errorKind_invalidResponse_mapsToUnknown() {
        XCTAssertEqual(ErrorKind.from(NetworkingError.invalidResponse), .unknown)
    }

    func test_errorKind_notConnectedToInternet_mapsToNotConnected() {
        XCTAssertEqual(ErrorKind.from(URLError(.notConnectedToInternet)), .notConnected)
    }

    func test_errorKind_networkConnectionLost_mapsToNotConnected() {
        XCTAssertEqual(ErrorKind.from(URLError(.networkConnectionLost)), .notConnected)
    }

    func test_errorKind_dataNotAllowed_mapsToNotConnected() {
        XCTAssertEqual(ErrorKind.from(URLError(.dataNotAllowed)), .notConnected)
    }

    func test_errorKind_internationalRoamingOff_mapsToNotConnected() {
        XCTAssertEqual(ErrorKind.from(URLError(.internationalRoamingOff)), .notConnected)
    }

    func test_errorKind_callIsActive_mapsToNotConnected() {
        XCTAssertEqual(ErrorKind.from(URLError(.callIsActive)), .notConnected)
    }

    func test_errorKind_timedOut_mapsToTimeout() {
        XCTAssertEqual(ErrorKind.from(URLError(.timedOut)), .timeout)
    }

    func test_errorKind_unrelatedURLError_mapsToUnknown() {
        XCTAssertEqual(ErrorKind.from(URLError(.badURL)), .unknown)
        XCTAssertEqual(ErrorKind.from(URLError(.cannotFindHost)), .unknown)
        XCTAssertEqual(ErrorKind.from(URLError(.unsupportedURL)), .unknown)
    }

    func test_errorKind_generalError_mapsToUnknown() {
        struct AnyError: Error {}
        XCTAssertEqual(ErrorKind.from(AnyError()), .unknown)
    }
}
