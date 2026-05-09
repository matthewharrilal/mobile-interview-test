// HotelListings.swift
// Feature: HotelListings — POST /api/search/algolia_hotels_v7 for a selected place.
// MVI: HotelListingsState + HotelListingsIntent + HotelListingsViewModel.

import Foundation

// MARK: - State

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

    private let client: HotelsClient
    private let logger: LogClient
    private var fetchTask: Task<Void, Never>?

    init(
        location: Place,
        client: HotelsClient = .preview,
        logger: LogClient = .silent
    ) {
        self.state = HotelListingsState(location: location, status: .idle)
        self.client = client
        self.logger = logger
    }

    func send(_ intent: HotelListingsIntent) {
        switch intent {
        case .appeared:
            startFetch()
        case .retryTapped:
            startFetch()
        case .backToSearchTapped:
            // Pop is handled by the View via dismiss environment.
            break
        }
    }

    private func startFetch() {
        fetchTask?.cancel()
        state.status = .loading
        fetchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await self.client.search(self.state.location)
                try Task.checkCancellation()
                if response.hotels.isEmpty {
                    self.state.status = .empty
                } else {
                    self.state.status = .loaded(.init(hotels: response.hotels, currency: response.currency))
                }
            } catch is CancellationError {
                // silent
            } catch let urlError as URLError where urlError.code == .cancelled {
                // silent
            } catch {
                self.state.status = .failed(message: "We couldn't reach our servers. Check your connection and try again.")
            }
        }
    }
}
