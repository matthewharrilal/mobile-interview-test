// HotelListingsSectionsTests.swift
// Pins HotelListingsState.Loaded.buildSections business logic in isolation.
// The 40-line section pipeline (top picks, walking distance, best value,
// fallback All) was previously only covered indirectly via integration
// tests — these tests pin the rules so a future contributor can't silently
// change "top picks = 5 max" or "walking ≤ 1.5 mi" without a red test.

import XCTest
@testable import ResortPass

final class HotelListingsSectionsTests: XCTestCase {

    // MARK: - Fixtures

    private func hotel(
        id: Int,
        rating: Double? = 4.0,
        distance: Double? = nil,
        price: Double? = nil,
        productName: String? = nil,
        vibe: String? = nil
    ) -> Hotel {
        Hotel(
            id: id,
            name: "Hotel \(id)",
            imageURL: nil,
            imageURLs: [],
            rating: rating,
            reviewCount: 0,
            hotelStar: nil,
            distanceMiles: distance,
            distanceText: nil,
            cityName: nil,
            stateCode: nil,
            productName: productName,
            primaryVibe: vibe,
            cheapestPrice: price
        )
    }

    // MARK: - Top picks

    func test_topPicks_capsAtFiveByRatingDescending() {
        let hotels = (1...10).map { hotel(id: $0, rating: Double($0)) }
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .all)
        let topPicks = sections.first { $0.id == "top-picks" }
        XCTAssertNotNil(topPicks, "Top picks section must be present when there are rated hotels")
        XCTAssertEqual(topPicks?.hotels.count, 5)
        XCTAssertEqual(topPicks?.hotels.map(\.id), [10, 9, 8, 7, 6], "Top 5 by rating descending")
    }

    func test_topPicks_treatsMissingRatingAsZero() {
        let hotels = [
            hotel(id: 1, rating: 5.0),
            hotel(id: 2, rating: nil),
            hotel(id: 3, rating: 3.0)
        ]
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .all)
        let topPicks = sections.first { $0.id == "top-picks" }
        XCTAssertEqual(topPicks?.hotels.first?.id, 1, "Highest rating first")
        // Missing rating should sort last (treated as 0).
        XCTAssertEqual(topPicks?.hotels.last?.id, 2)
    }

    // MARK: - Walking distance

    func test_walking_includesOnlyHotelsWithin1Point5Miles() {
        let hotels = [
            hotel(id: 1, distance: 0.5),
            hotel(id: 2, distance: 1.5),     // boundary inclusive
            hotel(id: 3, distance: 1.5001),  // just over
            hotel(id: 4, distance: nil)
        ]
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .all)
        let walking = sections.first { $0.id == "walking" }
        let ids = walking?.hotels.map(\.id).sorted()
        XCTAssertEqual(ids, [1, 2], "Only hotels with distance ≤ 1.5 mi qualify")
    }

    func test_walking_omittedWhenNoHotelsQualify() {
        let hotels = [hotel(id: 1, distance: 10)]
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .all)
        XCTAssertNil(sections.first { $0.id == "walking" }, "No walking section when zero hotels qualify")
    }

    // MARK: - Best value

    func test_bestValue_capsAtFiveByPriceAscending() {
        let hotels = (1...10).map { hotel(id: $0, price: Double($0) * 50) }
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .all)
        let bestValue = sections.first { $0.id == "best-value" }
        XCTAssertEqual(bestValue?.hotels.count, 5)
        XCTAssertEqual(bestValue?.hotels.map(\.id), [1, 2, 3, 4, 5], "Cheapest 5 by price ascending")
    }

    func test_bestValue_excludesHotelsWithoutPrice() {
        let hotels = [
            hotel(id: 1, price: 100),
            hotel(id: 2, price: nil),
            hotel(id: 3, price: 50)
        ]
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .all)
        let bestValue = sections.first { $0.id == "best-value" }
        XCTAssertEqual(bestValue?.hotels.map(\.id), [3, 1], "Hotels without a price are excluded")
    }

    // MARK: - All section (fallback)

    func test_all_includesHotelsNotInAnyOtherSection() {
        // Top picks captures the top-5 by rating; this gives us extras that
        // didn't land in any specialized section.
        let hotels = (1...8).map { hotel(id: $0, rating: 1.0) }  // all same rating → top-5 captures 1-5 by stable sort
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .all)
        let all = sections.first { $0.id == "all" }
        XCTAssertNotNil(all, "All section appears when hotels remain after specialized sections")
        XCTAssertEqual(all?.hotels.count ?? 0, 3, "Hotels 6, 7, 8 land in All since 1-5 are top-picks")
    }

    func test_all_omittedWhenAllHotelsAreInOtherSections() {
        let hotels = (1...3).map { hotel(id: $0, rating: Double($0), distance: 0.5, price: Double($0)) }
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .all)
        XCTAssertNil(sections.first { $0.id == "all" }, "No All section when every hotel is in specialized sections")
    }

    // MARK: - Filter integration

    func test_filterPool_keepsOnlyPoolMatches() {
        let hotels = [
            hotel(id: 1, productName: "Pool Pass"),
            hotel(id: 2, productName: "Spa Day"),
            hotel(id: 3, vibe: "pool-side oasis")
        ]
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .pool)
        let allIds = sections.flatMap(\.hotels).map(\.id).sorted()
        let unique = Array(Set(allIds)).sorted()
        XCTAssertEqual(unique, [1, 3], "Only hotels matching the pool term survive the filter")
    }

    func test_filterAll_keepsEverything() {
        let hotels = (1...3).map { hotel(id: $0) }
        let sections = HotelListingsState.Loaded.buildSections(hotels: hotels, activeFilter: .all)
        let allIds = Set(sections.flatMap(\.hotels).map(\.id))
        XCTAssertEqual(allIds, [1, 2, 3])
    }

    // MARK: - Empty input

    func test_emptyHotels_returnsNoSections() {
        let sections = HotelListingsState.Loaded.buildSections(hotels: [], activeFilter: .all)
        XCTAssertTrue(sections.isEmpty)
    }
}
