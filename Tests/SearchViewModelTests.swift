// SearchViewModelTests.swift
// Reducer behavior: status transitions, debounce, cancellation, stale-response guard.

import XCTest
@testable import ResortPass

@MainActor
final class SearchViewModelTests: XCTestCase {

    // MARK: - Status transitions

    func test_queryChanged_emptyString_returnsToIdle() async {
        let vm = makeVM(client: .preview)
        vm.send(.queryChanged("newport"))
        await sleepShort()
        vm.send(.queryChanged(""))
        XCTAssertEqual(vm.state.query, "")
        if case .idle = vm.state.status { } else {
            XCTFail("Expected .idle, got \(vm.state.status)")
        }
    }

    func test_queryChanged_whitespaceOnly_treatedAsEmpty() async {
        let vm = makeVM(client: .preview)
        vm.send(.queryChanged("   "))
        await sleepShort()
        if case .idle = vm.state.status { } else {
            XCTFail("Whitespace-only query must be treated as empty")
        }
    }

    func test_queryChanged_nonEmpty_transitionsToLoadingThenLoaded() async {
        let vm = makeVM(client: .preview)
        vm.send(.queryChanged("newport"))
        // Synchronously after send, state should be .loading (debounce hasn't fired yet).
        if case .loading = vm.state.status { } else {
            XCTFail("Expected .loading immediately after queryChanged, got \(vm.state.status)")
        }
        // After debounce + fetch, .loaded with non-empty results.
        try? await Task.sleep(for: .milliseconds(800))
        if case .loaded(let places) = vm.state.status {
            XCTAssertFalse(places.isEmpty, "Preview client returns Newport fixtures")
        } else {
            XCTFail("Expected .loaded, got \(vm.state.status)")
        }
    }

    func test_queryChanged_clientReturnsEmpty_transitionsToEmpty() async {
        let emptyClient = SearchClient { _ in [] }
        let vm = makeVM(client: emptyClient)
        vm.send(.queryChanged("anything"))
        try? await Task.sleep(for: .milliseconds(800))
        if case .empty = vm.state.status { } else {
            XCTFail("Empty results must transition to .empty (not .loaded([]))")
        }
    }

    func test_queryChanged_clientThrows_transitionsToFailed() async {
        let vm = makeVM(client: .failing)
        vm.send(.queryChanged("anything"))
        try? await Task.sleep(for: .milliseconds(800))
        if case .failed = vm.state.status { } else {
            XCTFail("Throwing client must transition to .failed, got \(vm.state.status)")
        }
    }

    // MARK: - Cancellation

    func test_rapidQueryChanges_onlyLatestQueryFires() async {
        // The previous fetchTask should be cancelled before the new one fires.
        var calls: [String] = []
        let recordingClient = SearchClient { query in
            calls.append(query)
            return Place.fixturesMatching(query)
        }
        let vm = makeVM(client: recordingClient)
        vm.send(.queryChanged("n"))
        vm.send(.queryChanged("ne"))
        vm.send(.queryChanged("new"))
        vm.send(.queryChanged("newp"))
        vm.send(.queryChanged("newport"))
        try? await Task.sleep(for: .milliseconds(800))
        // Only the latest query should have hit the client (debounce + cancellation).
        XCTAssertEqual(calls, ["newport"], "Only the final query should fire after debounce")
    }

    // MARK: - Place selection guard

    func test_placeSelected_withNullCoords_transitionsToFailedNotNavigation() {
        let vm = makeVM(client: .preview)
        let nullCoordPlace = Place(
            placeID: 999, objectID: "Brooklyn, Florida", name: "Brooklyn, Florida",
            type: "city", cityName: "Brooklyn", stateCode: "FL", countryCode: "US",
            latitude: nil, longitude: nil
        )
        vm.send(.placeSelected(nullCoordPlace))
        if case .failed = vm.state.status { } else {
            XCTFail("Place with null coords must surface .failed instead of pushing into broken hotels")
        }
        XCTAssertTrue(vm.state.path.isEmpty, "Path must NOT be appended for unusable coords")
    }

    func test_placeSelected_withValidCoords_pushesDestination() {
        let vm = makeVM(client: .preview)
        let validPlace = Place(
            placeID: 1, objectID: "X", name: "X",
            type: "city", cityName: "X", stateCode: "NY", countryCode: "US",
            latitude: 40.7, longitude: -73.7
        )
        vm.send(.placeSelected(validPlace))
        XCTAssertEqual(vm.state.path.count, 1)
    }

    // MARK: - Debounce + retry

    func test_debounceConstant_isExactly500ms_perSpec() {
        // PDF spec: "A new request should only be made 500 milliseconds after
        // the user's last keystroke." Anchor the constant so a future change
        // breaks this test loudly.
        XCTAssertEqual(Networking.Constants.searchDebounce, .milliseconds(500))
    }

    func test_retryTapped_afterFailure_refetchesUsingStoredQuery() async {
        var calls: [String] = []
        var shouldFail = true
        let client = SearchClient { query in
            calls.append(query)
            if shouldFail { throw NetworkingError.invalidResponse }
            return Place.fixturesMatching(query)
        }
        let vm = makeVM(client: client)
        vm.send(.queryChanged("newport"))
        try? await Task.sleep(for: .milliseconds(800))
        if case .failed = vm.state.status { } else {
            XCTFail("Setup failed: expected initial .failed, got \(vm.state.status)")
            return
        }
        // Now flip the client to succeed and retry
        shouldFail = false
        vm.send(.retryTapped)
        try? await Task.sleep(for: .milliseconds(800))
        if case .loaded = vm.state.status { } else {
            XCTFail("Expected .loaded after retry, got \(vm.state.status)")
        }
        XCTAssertEqual(calls.count, 2, "Retry should fire a second client call")
        XCTAssertEqual(calls.last, "newport", "Retry should use the stored query")
    }

    // MARK: - Helpers

    private func makeVM(client: SearchClient) -> SearchViewModel {
        SearchViewModel(client: client, clock: .init(), logger: .silent)
    }

    private func sleepShort() async {
        try? await Task.sleep(for: .milliseconds(700))
    }
}
