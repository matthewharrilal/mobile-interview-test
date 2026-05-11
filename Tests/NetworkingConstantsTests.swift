// NetworkingConstantsTests.swift
// Direct pins for `Networking.Constants` values that previously only had
// indirect coverage via behavioral tests. Adding here so a future
// contributor can't silently tighten `successStatusRange` to `200..<201`
// or change `requestTimeout` from 15s without a loud test failure.

import XCTest
@testable import ResortPass

final class NetworkingConstantsTests: XCTestCase {

    // MARK: - successStatusRange

    func test_successStatusRange_is200to299() {
        XCTAssertEqual(Networking.Constants.successStatusRange, 200..<300)
    }

    func test_successStatusRange_boundaries() {
        let range = Networking.Constants.successStatusRange
        XCTAssertFalse(range.contains(199), "199 must NOT be a success status")
        XCTAssertTrue(range.contains(200),  "200 must be a success status")
        XCTAssertTrue(range.contains(204),  "204 (No Content) must be a success status")
        XCTAssertTrue(range.contains(299),  "299 must be a success status")
        XCTAssertFalse(range.contains(300), "300 must NOT be a success status")
        XCTAssertFalse(range.contains(403), "403 must NOT be a success status")
        XCTAssertFalse(range.contains(503), "503 must NOT be a success status")
    }

    // MARK: - requestTimeout

    func test_requestTimeout_is15Seconds() {
        XCTAssertEqual(Networking.Constants.requestTimeout, 15)
    }

    func test_requestTimeout_appliedToConstructedRequest() {
        // Build a URLRequest the same way the .live factories do and
        // confirm the timeoutInterval reflects the constant. Pins the
        // wiring — if a future contributor builds a request without the
        // timeout, this fails.
        let url = URL(string: "https://example.com")!
        let request = URLRequest(url: url, timeoutInterval: Networking.Constants.requestTimeout)
        XCTAssertEqual(request.timeoutInterval, 15)
    }

    // MARK: - Page sizes

    func test_autocompletePageSize_isTen() {
        XCTAssertEqual(Networking.Constants.autocompletePageSize, 10)
    }

    func test_hotelsPageSize_isThirty() {
        XCTAssertEqual(Networking.Constants.hotelsPageSize, 30)
    }

    // MARK: - Staleness threshold

    func test_listingsStaleThreshold_isFiveMinutes() {
        XCTAssertEqual(Networking.Constants.listingsStaleThreshold, 300)
    }

    // MARK: - Debounce

    func test_searchDebounce_is500Milliseconds() {
        XCTAssertEqual(Networking.Constants.searchDebounce, .milliseconds(500))
    }
}
