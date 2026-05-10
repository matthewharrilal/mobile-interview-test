// SpecComplianceTests.swift
// Targeted coverage for the interview prompt's explicit requirements + the
// edge cases the existing reducer tests don't exercise. Each test names the
// behavior it pins so a future refactor can't silently regress a spec'd
// guarantee.

import XCTest
@testable import ResortPass

@MainActor
final class SpecComplianceTests: XCTestCase {

    // MARK: - Place.typeBadge mapping (UI label correctness)

    func test_typeBadge_city_returnsCity() {
        let p = makePlace(type: "city")
        XCTAssertEqual(p.typeBadge, "City")
    }

    func test_typeBadge_alias_returnsArea_notNearby() {
        // Pinning the rename: "Nearby" implied a spatial relationship that
        // the API doesn't model. "Newport, Tennessee" (alias) is not nearby
        // "Newport, California" — they're matches in different states.
        let p = makePlace(type: "alias")
        XCTAssertEqual(p.typeBadge, "Area")
        XCTAssertNotEqual(p.typeBadge, "Nearby", "Reverted-to-Nearby would mislead users")
    }

    func test_typeBadge_country_returnsCountry() {
        XCTAssertEqual(makePlace(type: "country").typeBadge, "Country")
    }

    func test_typeBadge_unknownType_returnsEmpty() {
        // Forward-compatible: an API addition (e.g. "neighborhood") should
        // not crash the row layout. Empty string lets the View skip the line.
        XCTAssertEqual(makePlace(type: "neighborhood").typeBadge, "")
    }

    // MARK: - Spec: 500ms debounce — observed timing

    func test_debounce_observedTiming_callDoesNotFireBefore500ms() async {
        // Spec: "A new request should only be made 500 milliseconds after
        // the user's last keystroke." We verify behaviorally — keystroke
        // at t=0, sample at t=400ms, no call should have fired yet.
        var calls: [String] = []
        let recordingClient = SearchClient { query in
            calls.append(query)
            return Place.fixturesMatching(query)
        }
        let vm = SearchViewModel(client: recordingClient, clock: .init(), logger: .silent)
        vm.send(.queryChanged("newport"))
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(calls.isEmpty, "Client must NOT be called before 500ms debounce window elapses; got \(calls)")
    }

    func test_debounce_observedTiming_callFiresAfter500ms() async {
        var calls: [String] = []
        let recordingClient = SearchClient { query in
            calls.append(query)
            return Place.fixturesMatching(query)
        }
        let vm = SearchViewModel(client: recordingClient, clock: .init(), logger: .silent)
        vm.send(.queryChanged("newport"))
        try? await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(calls, ["newport"], "Client must fire exactly once after the 500ms debounce window")
    }

    // MARK: - Spec: cancellation — stale response can't clobber

    func test_staleResponseGuard_olderQueryResponseDoesNotClobberNewerState() async {
        // A slow client returns a response well after a newer query has been
        // sent. The stale response must NOT overwrite the loaded state of the
        // newer query. The view-model has an explicit check
        // `query == self.state.query.trimmingCharacters(in: .whitespaces)`
        // — this test pins that guard.
        actor SlowClient {
            var calls: [(String, Date)] = []
            func search(_ q: String) async throws -> [Place] {
                calls.append((q, Date()))
                // First query is slow; subsequent queries return immediately.
                if calls.count == 1 {
                    try await Task.sleep(for: .milliseconds(800))
                }
                return Place.fixturesMatching(q)
            }
        }
        let backing = SlowClient()
        let client = SearchClient { q in try await backing.search(q) }
        let vm = SearchViewModel(client: client, clock: .init(), logger: .silent)

        vm.send(.queryChanged("newport"))
        try? await Task.sleep(for: .milliseconds(550))
        // First fetch is mid-flight (debounce + slow response). Now type a new query.
        vm.send(.queryChanged("jamaica"))
        try? await Task.sleep(for: .milliseconds(1200))

        // Final state must reflect "jamaica", not "newport"'s late response.
        XCTAssertEqual(vm.state.query, "jamaica")
        if case .loaded(let places) = vm.state.status {
            XCTAssertEqual(places.first?.name, "Jamaica", "Final loaded state must be jamaica's results, not newport's late response")
        } else {
            XCTFail("Expected .loaded for jamaica, got \(vm.state.status)")
        }
    }

    // MARK: - Backspace-to-empty

    func test_queryChanged_backspaceToEmpty_returnsToIdle() async {
        let vm = SearchViewModel(client: .preview, clock: .init(), logger: .silent)
        vm.send(.queryChanged("newp"))
        try? await Task.sleep(for: .milliseconds(700))
        // Backspace 4 chars rapidly — should land in idle, not stuck in loading.
        vm.send(.queryChanged("new"))
        vm.send(.queryChanged("ne"))
        vm.send(.queryChanged("n"))
        vm.send(.queryChanged(""))
        if case .idle = vm.state.status { } else {
            XCTFail("Backspacing to empty must return to .idle, got \(vm.state.status)")
        }
    }

    // MARK: - Clear during in-flight states

    func test_clearTapped_during_loading_cancelsAndReturnsIdle() async {
        let neverFinishingClient = SearchClient { _ in
            try await Task.sleep(for: .seconds(60))
            return []
        }
        let vm = SearchViewModel(client: neverFinishingClient, clock: .init(), logger: .silent)
        vm.send(.queryChanged("newport"))
        try? await Task.sleep(for: .milliseconds(100))
        guard case .loading = vm.state.status else {
            XCTFail("Setup expected .loading; got \(vm.state.status)")
            return
        }
        vm.send(.clearTapped)
        XCTAssertEqual(vm.state.query, "")
        if case .idle = vm.state.status { } else {
            XCTFail(".clearTapped during .loading must cancel + return to .idle, got \(vm.state.status)")
        }
    }

    func test_clearTapped_during_failed_returnsToIdle() async {
        let vm = SearchViewModel(client: .failing, clock: .init(), logger: .silent)
        vm.send(.queryChanged("newport"))
        try? await Task.sleep(for: .milliseconds(800))
        guard case .failed = vm.state.status else {
            XCTFail("Setup expected .failed")
            return
        }
        vm.send(.clearTapped)
        if case .idle = vm.state.status { } else {
            XCTFail(".clearTapped from .failed must return to .idle, got \(vm.state.status)")
        }
    }

    // MARK: - Place selection while loading

    func test_placeSelected_during_loading_navigatesAndDoesNotBlockOnFetch() async {
        // The user can pick a place from prior results even while a new
        // fetch is debouncing — selection should commit immediately.
        let neverFinishingClient = SearchClient { _ in
            try await Task.sleep(for: .seconds(60))
            return []
        }
        let vm = SearchViewModel(client: neverFinishingClient, clock: .init(), logger: .silent)
        let valid = makePlace(type: "city", lat: 40.7, lon: -73.7)
        vm.send(.queryChanged("anything"))
        vm.send(.placeSelected(valid))
        XCTAssertEqual(vm.state.path.count, 1, "Place selection must commit even with a fetch in flight")
    }

    // MARK: - State cycle: idle → loaded → loaded → empty

    func test_stateCycle_loadedToLoadedToEmpty_cleanlyTransitions() async {
        var nextResult: [Place] = []
        let client = SearchClient { _ in nextResult }
        let vm = SearchViewModel(client: client, clock: .init(), logger: .silent)

        nextResult = Place.fixturesMatching("newport")
        vm.send(.queryChanged("newport"))
        try? await Task.sleep(for: .milliseconds(700))
        guard case .loaded = vm.state.status else { XCTFail("phase 1: expected .loaded"); return }

        nextResult = Place.fixturesMatching("jamaica")
        vm.send(.queryChanged("jamaica"))
        try? await Task.sleep(for: .milliseconds(700))
        guard case .loaded = vm.state.status else { XCTFail("phase 2: expected .loaded"); return }

        nextResult = []
        vm.send(.queryChanged("zzz"))
        try? await Task.sleep(for: .milliseconds(700))
        if case .empty = vm.state.status { } else {
            XCTFail("phase 3: expected .empty for unmatched query, got \(vm.state.status)")
        }
    }

    // MARK: - HotelListings: regression test for dismiss-no-refetch

    func test_hotelListings_appearedWhenAlreadyLoaded_doesNotRefetch() async {
        // Regression for the "dismiss detail → screen flashes skeleton + refetches"
        // bug. After the listings have loaded, a re-appear (e.g. user pops a
        // pushed detail off the navigation stack) MUST NOT tear the loaded
        // state down to .loading and re-network. Only .idle/.failed/.empty
        // should re-fetch.
        var calls = 0
        let client = HotelsClient { _ in
            calls += 1
            return HotelsSearchResponse(hotels: Hotel.previewFixtures, currency: .usd, total: 3)
        }
        let location = makePlace(type: "city", lat: 40.7, lon: -73.7)
        let vm = HotelListingsViewModel(location: location, client: client, logger: .silent)

        vm.send(.appeared)
        try? await Task.sleep(for: .milliseconds(300))
        guard case .loaded = vm.state.status else { XCTFail("Setup: expected .loaded"); return }
        XCTAssertEqual(calls, 1, "Phase 1: first appearance fetched once")

        // Simulate a re-appear from popping a detail off the nav stack.
        vm.send(.appeared)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(calls, 1, "Re-appearance with .loaded state must NOT trigger another fetch")
        if case .loaded = vm.state.status { } else {
            XCTFail("Re-appearance must preserve .loaded state, got \(vm.state.status)")
        }
    }

    func test_hotelListings_appearedFromFailed_doesRefetch() async {
        // Conjugate of the above: from .failed, re-appearing SHOULD refetch
        // — otherwise the user has no way to recover automatically when
        // returning to the screen after a transient network error.
        var calls = 0
        var shouldFail = true
        let client = HotelsClient { _ in
            calls += 1
            if shouldFail { throw NetworkingError.invalidResponse }
            return HotelsSearchResponse(hotels: Hotel.previewFixtures, currency: .usd, total: 3)
        }
        let location = makePlace(type: "city", lat: 40.7, lon: -73.7)
        let vm = HotelListingsViewModel(location: location, client: client, logger: .silent)

        vm.send(.appeared)
        try? await Task.sleep(for: .milliseconds(300))
        guard case .failed = vm.state.status else { XCTFail("Setup: expected .failed"); return }

        // Network recovers; re-appear should retry.
        shouldFail = false
        vm.send(.appeared)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(calls, 2, "Re-appearance from .failed must refetch (recovery path)")
        if case .loaded = vm.state.status { } else {
            XCTFail("Expected .loaded after recovery, got \(vm.state.status)")
        }
    }

    func test_hotelListings_filterChanged_preservesLoadedHotels() async {
        // Filter changes must apply to the existing loaded data — they
        // must NOT trigger a re-fetch (that's a state-mutation, not a
        // data-fetch action).
        var calls = 0
        let client = HotelsClient { _ in
            calls += 1
            return HotelsSearchResponse(hotels: Hotel.previewFixtures, currency: .usd, total: 3)
        }
        let location = makePlace(type: "city", lat: 40.7, lon: -73.7)
        let vm = HotelListingsViewModel(location: location, client: client, logger: .silent)
        vm.send(.appeared)
        try? await Task.sleep(for: .milliseconds(300))
        guard case .loaded = vm.state.status else { XCTFail("Setup: expected .loaded"); return }

        vm.send(.filterChanged(.pool))
        XCTAssertEqual(calls, 1, "Filter change must NOT trigger another fetch")
        if case .loaded(let loaded) = vm.state.status {
            XCTAssertEqual(loaded.activeFilter, .pool, "Active filter must update")
        } else {
            XCTFail("Filter change must preserve .loaded, got \(vm.state.status)")
        }
    }

    // MARK: - Helpers

    private func makePlace(type: String, lat: Double? = 0, lon: Double? = 0) -> Place {
        Place(
            placeID: 1, objectID: "x", name: "X",
            type: type, cityName: "X", stateCode: "NY", countryCode: "US",
            latitude: lat, longitude: lon
        )
    }
}
