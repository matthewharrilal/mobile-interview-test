// SearchClientLiveTests.swift
// Exercises SearchClient.live directly via a stubbed HTTPClient.
// Closes the test-adequacy gap where the .live factory was only reached
// indirectly through the ViewModel — regressions in logging, cancellation
// translation, or decode path were previously invisible.

import XCTest
@testable import ResortPass

final class SearchClientLiveTests: XCTestCase {

    // MARK: - Happy path

    func test_search_decodesPlacesFromValidResponse() async throws {
        let json = """
        [
          { "id": 1, "objectID": "Newport", "name": "Newport, RI", "type": "city",
            "city_name": "Newport", "state_code": "RI", "country_code": "US",
            "latitude": 41.49, "longitude": -71.31 }
        ]
        """
        let http = stubHTTPClient(responseData: Data(json.utf8))
        let client = SearchClient.live(http: http, logger: .silent)
        let places = try await client.search("newport")
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.name, "Newport, RI")
    }

    // MARK: - Lossy decode

    func test_search_dropsOneMalformedRowKeepsRest() async throws {
        // Pins that the lossy-array decode is wired through .live (not just
        // via Decoders.decodeLossy in isolation).
        let json = """
        [
          { "id": 1, "objectID": "ok", "name": "OK Place", "type": "city",
            "city_name": "OK", "state_code": "CA", "country_code": "US",
            "latitude": 0, "longitude": 0 },
          { "id": "bad-type", "objectID": "broken" }
        ]
        """
        let http = stubHTTPClient(responseData: Data(json.utf8))
        let client = SearchClient.live(http: http, logger: .silent)
        let places = try await client.search("anything")
        XCTAssertEqual(places.count, 1)
    }

    // MARK: - Error paths

    func test_search_propagatesNetworkingError() async {
        let http = HTTPClient { _ in throw NetworkingError.status(503) }
        let client = SearchClient.live(http: http, logger: .silent)
        do {
            _ = try await client.search("x")
            XCTFail("Expected NetworkingError.status(503)")
        } catch let NetworkingError.status(code) {
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("Wrong error type: \(type(of: error))")
        }
    }

    func test_search_wrapsDecodingErrorAsNetworkingDecode() async {
        // executeJSON wraps DecodingError as NetworkingError.decode so the
        // surfaced error type at the VM seam is uniform.
        // Lossy decode of an array won't raise DecodingError (it silently
        // drops bad rows), so we cause a top-level type mismatch:
        // expecting `[Place]` but receiving an object.
        let bogus = Data("{\"not\": \"an array\"}".utf8)
        let http = stubHTTPClient(responseData: bogus)
        let client = SearchClient.live(http: http, logger: .silent)
        do {
            _ = try await client.search("x")
            XCTFail("Expected NetworkingError.decode")
        } catch let NetworkingError.decode(underlying) {
            _ = underlying  // shape confirmed via case match
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Cancellation translation

    func test_search_translatesURLCancelToCancellationError() async {
        let http = HTTPClient { _ in throw URLError(.cancelled) }
        let client = SearchClient.live(http: http, logger: .silent)
        do {
            _ = try await client.search("x")
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - URL shape

    func test_search_buildsCorrectURL() async throws {
        var capturedURL: URL?
        let http = HTTPClient { request in
            capturedURL = request.url
            return (Data("[]".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = SearchClient.live(http: http, logger: .silent)
        _ = try await client.search("newport beach")
        XCTAssertEqual(
            capturedURL?.absoluteString,
            "https://staging-app.resortpass.com/api/search/places/autocomplete?terms=newport%20beach&limit=10&offset=0"
        )
    }

    // MARK: - Helpers

    private func stubHTTPClient(responseData: Data, statusCode: Int = 200) -> HTTPClient {
        HTTPClient { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://stub.test")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (responseData, response)
        }
    }
}
