// HotelListingsViewModelTests.swift
// Mirror of SearchViewModelTests for the HotelListings reducer:
// status transitions, retry, cancellation behavior.

import XCTest
@testable import ResortPass

@MainActor
final class HotelListingsViewModelTests: XCTestCase {

    private let location = Place(
        placeID: 1, objectID: "X", name: "Test Place",
        type: "city", cityName: "X", stateCode: "NY", countryCode: "US",
        latitude: 40.7, longitude: -73.7
    )

    func test_appeared_transitionsToLoadingThenLoaded() async {
        let vm = HotelListingsViewModel(location: location, client: .preview, logger: .silent)
        vm.send(.appeared)
        if case .loading = vm.state.status { } else {
            XCTFail("Expected immediate .loading after .appeared, got \(vm.state.status)")
        }
        try? await Task.sleep(for: .milliseconds(300))
        if case .loaded(let loaded) = vm.state.status {
            XCTAssertFalse(loaded.hotels.isEmpty, "Preview client returns fixtures")
        } else {
            XCTFail("Expected .loaded, got \(vm.state.status)")
        }
    }

    func test_appeared_clientReturnsEmpty_transitionsToEmpty() async {
        let emptyClient = HotelsClient { _ in
            HotelsSearchResponse(hotels: [], currency: .usd, total: 0)
        }
        let vm = HotelListingsViewModel(location: location, client: emptyClient, logger: .silent)
        vm.send(.appeared)
        try? await Task.sleep(for: .milliseconds(300))
        if case .empty = vm.state.status { } else {
            XCTFail("Expected .empty for zero hotels, got \(vm.state.status)")
        }
    }

    func test_appeared_clientThrows_transitionsToFailed() async {
        let vm = HotelListingsViewModel(location: location, client: .failing, logger: .silent)
        vm.send(.appeared)
        try? await Task.sleep(for: .milliseconds(300))
        if case .failed = vm.state.status { } else {
            XCTFail("Expected .failed, got \(vm.state.status)")
        }
    }

    func test_retryTapped_afterFailure_refetches() async {
        var calls = 0
        var shouldFail = true
        let client = HotelsClient { _ in
            calls += 1
            if shouldFail { throw NetworkingError.invalidResponse }
            return HotelsSearchResponse(hotels: Hotel.previewFixtures, currency: .usd, total: 3)
        }
        let vm = HotelListingsViewModel(location: location, client: client, logger: .silent)
        vm.send(.appeared)
        try? await Task.sleep(for: .milliseconds(300))
        if case .failed = vm.state.status { } else {
            XCTFail("Setup failed")
            return
        }
        shouldFail = false
        vm.send(.retryTapped)
        try? await Task.sleep(for: .milliseconds(300))
        if case .loaded = vm.state.status { } else {
            XCTFail("Expected .loaded after retry, got \(vm.state.status)")
        }
        XCTAssertEqual(calls, 2)
    }

    func test_storedLocation_isSentToClient() async {
        var receivedLocation: Place?
        let recorder = HotelsClient { place in
            receivedLocation = place
            return HotelsSearchResponse(hotels: [], currency: .usd, total: 0)
        }
        let vm = HotelListingsViewModel(location: location, client: recorder, logger: .silent)
        vm.send(.appeared)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(receivedLocation, location)
    }
}
