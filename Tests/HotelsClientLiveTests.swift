// HotelsClientLiveTests.swift
// Exercises HotelsClient.live directly via a stubbed HTTPClient. Closes the
// test-adequacy gap where the .live factory was only reached indirectly
// through the ViewModel, and where the body-shape test previously
// reconstructed the JSON independently rather than exercising the actual
// client request.

import XCTest
@testable import ResortPass

final class HotelsClientLiveTests: XCTestCase {

    private let testLocation = Place(
        placeID: 1, objectID: "X", name: "Test City",
        type: "city", cityName: "Test", stateCode: "NY", countryCode: "US",
        latitude: 33.6189, longitude: -117.9298
    )

    // MARK: - Body shape (closes the NetworkingLayerTests gap)

    func test_search_buildsRequestBodyMatchingInterviewSpec() async throws {
        var capturedBody: Data?
        let http = HTTPClient { request in
            capturedBody = request.httpBody
            return (Data(#"{"hotels": [], "total": 0}"#.utf8), Self.okResponse(for: request))
        }
        let client = HotelsClient.live(http: http, logger: .silent)
        _ = try await client.search(testLocation)

        let body = try XCTUnwrap(capturedBody)
        let decoded = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        XCTAssertEqual(decoded["limit"] as? Int, 30)
        XCTAssertEqual(decoded["offset"] as? Int, 0)
        let location = decoded["location"] as! [String: Any]
        let lat = try XCTUnwrap(location["latitude"] as? Double)
        let lng = try XCTUnwrap(location["longitude"] as? Double)
        XCTAssertEqual(lat, 33.6189, accuracy: 0.0001)
        XCTAssertEqual(lng, -117.9298, accuracy: 0.0001)
    }

    func test_search_setsPostMethodAndJSONContentType() async throws {
        var capturedMethod: String?
        var capturedContentType: String?
        let http = HTTPClient { request in
            capturedMethod = request.httpMethod
            capturedContentType = request.value(forHTTPHeaderField: "Content-Type")
            return (Data(#"{"hotels": []}"#.utf8), Self.okResponse(for: request))
        }
        let client = HotelsClient.live(http: http, logger: .silent)
        _ = try await client.search(testLocation)
        XCTAssertEqual(capturedMethod, "POST")
        XCTAssertEqual(capturedContentType, "application/json")
    }

    // MARK: - Happy path

    func test_search_mapsWireResponseToDomain() async throws {
        let json = """
        {
          "hotels": [
            { "id": 1, "name": "First Hotel", "rating": 4.5, "reviews": 100 },
            { "id": 2, "name": "Second Hotel", "rating": 4.0, "reviews": 50 }
          ],
          "currency": { "symbol": "$", "iso_code": "USD" },
          "total": 2
        }
        """
        let http = stubHTTPClient(responseData: Data(json.utf8))
        let client = HotelsClient.live(http: http, logger: .silent)
        let response = try await client.search(testLocation)
        XCTAssertEqual(response.hotels.count, 2)
        XCTAssertEqual(response.currency.code, "USD")
        XCTAssertEqual(response.total, 2)
    }

    func test_search_fallsBackToHotelsCountWhenTotalMissing() async throws {
        let json = """
        { "hotels": [{ "id": 1, "name": "Only" }] }
        """
        let http = stubHTTPClient(responseData: Data(json.utf8))
        let client = HotelsClient.live(http: http, logger: .silent)
        let response = try await client.search(testLocation)
        XCTAssertEqual(response.total, 1, "total falls back to hotels.count")
    }

    func test_search_fallsBackToUSDWhenCurrencyMissing() async throws {
        let json = """
        { "hotels": [], "total": 0 }
        """
        let http = stubHTTPClient(responseData: Data(json.utf8))
        let client = HotelsClient.live(http: http, logger: .silent)
        let response = try await client.search(testLocation)
        XCTAssertEqual(response.currency.code, "USD")
        XCTAssertEqual(response.currency.symbol, "$")
    }

    // MARK: - Lossy decode

    func test_search_dropsOneMalformedHotelKeepsRest() async throws {
        let json = """
        {
          "hotels": [
            { "id": 1, "name": "Valid" },
            { "id": "bad", "name": "Broken" },
            { "id": 3, "name": "Another Valid" }
          ],
          "total": 3
        }
        """
        let http = stubHTTPClient(responseData: Data(json.utf8))
        let client = HotelsClient.live(http: http, logger: .silent)
        let response = try await client.search(testLocation)
        XCTAssertEqual(response.hotels.count, 2, "One bad hotel row drops; the other two survive")
    }

    // MARK: - Error paths

    func test_search_propagatesNetworkingError() async {
        let http = HTTPClient { _ in throw NetworkingError.status(503) }
        let client = HotelsClient.live(http: http, logger: .silent)
        do {
            _ = try await client.search(testLocation)
            XCTFail("Expected NetworkingError.status(503)")
        } catch let NetworkingError.status(code) {
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_search_translatesURLCancelToCancellationError() async {
        let http = HTTPClient { _ in throw URLError(.cancelled) }
        let client = HotelsClient.live(http: http, logger: .silent)
        do {
            _ = try await client.search(testLocation)
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - URL shape

    func test_search_targetsAlgoliaEndpoint() async throws {
        var capturedURL: URL?
        let http = HTTPClient { request in
            capturedURL = request.url
            return (Data(#"{"hotels": []}"#.utf8), Self.okResponse(for: request))
        }
        let client = HotelsClient.live(http: http, logger: .silent)
        _ = try await client.search(testLocation)
        XCTAssertEqual(
            capturedURL?.absoluteString,
            "https://staging-app.resortpass.com/api/search/algolia_hotels_v7"
        )
    }

    // MARK: - Helpers

    private func stubHTTPClient(responseData: Data, statusCode: Int = 200) -> HTTPClient {
        HTTPClient { request in
            (responseData, Self.okResponse(for: request, statusCode: statusCode))
        }
    }

    private static func okResponse(for request: URLRequest, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "https://stub.test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
