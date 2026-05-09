// HotelListings.swift
// Feature: HotelListings — POST /api/search/algolia_hotels_v7 for a selected place.
// MVI: HotelListingsState + HotelListingsIntent + HotelListingsViewModel.

import Foundation

// MARK: - State

/// Single source of truth for the HotelListings screen.
struct HotelListingsState: Equatable, Sendable {
    var location: Place
    var status: Status

    enum Status: Equatable, Sendable {
        case idle
        case loading
        case loaded(Loaded)
        case empty
        case failed(message: String)
    }

    struct Loaded: Equatable, Sendable {
        var hotels: [Hotel]
        var currency: Currency
    }
}

// MARK: - Intent

enum HotelListingsIntent: Sendable {
    case appeared
    case retryTapped
    case backToSearchTapped
}

// MARK: - ViewModel

@Observable
@MainActor
final class HotelListingsViewModel {
    private(set) var state: HotelListingsState

    init(location: Place) {
        self.state = HotelListingsState(location: location, status: .idle)
    }

    func send(_ intent: HotelListingsIntent) {
        // Reducer body lands in subsequent tasks. Stub for compile.
        _ = intent
    }
}
