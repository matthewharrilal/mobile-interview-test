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
        var activeFilter: Filter

        /// Filtered + sectioned hotels. Drives the curated section layout
        /// (Top picks, Within walking distance, etc.) instead of one flat list.
        var sections: [Section] {
            let base = hotels.filter(activeFilter.matches)
            var result: [Section] = []

            // Top picks: top-rated 5
            let topRated = base.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }.prefix(5)
            if !topRated.isEmpty {
                result.append(Section(id: "top-picks", title: "Top picks",
                                       subtitle: "Highest rated near you",
                                       hotels: Array(topRated)))
            }

            // Within walking distance: distance ≤ 1.5 mi
            let nearby = base.filter { ($0.distanceMiles ?? .infinity) <= 1.5 }
            if !nearby.isEmpty {
                result.append(Section(id: "walking",
                                       title: "Within walking distance",
                                       subtitle: nil,
                                       hotels: nearby))
            }

            // Best value: cheapest 5
            let bestValue = base.filter { $0.cheapestPrice != nil }
                .sorted { ($0.cheapestPrice ?? .infinity) < ($1.cheapestPrice ?? .infinity) }
                .prefix(5)
            if !bestValue.isEmpty {
                result.append(Section(id: "best-value", title: "Best value",
                                       subtitle: "Lowest day passes today",
                                       hotels: Array(bestValue)))
            }

            // All — falls back to flat list of remaining
            let alreadyShown = Set(result.flatMap { $0.hotels.map(\.id) })
            let remaining = base.filter { !alreadyShown.contains($0.id) }
            if !remaining.isEmpty {
                result.append(Section(id: "all", title: "All hotels",
                                       subtitle: "\(remaining.count) more in \(activeFilter.displayName)",
                                       hotels: remaining))
            }
            return result
        }
    }

    struct Section: Equatable, Sendable, Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let hotels: [Hotel]
    }

    enum Filter: String, CaseIterable, Sendable, Identifiable {
        case all
        case pool
        case spa
        case adults
        case pets
        case wellness

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all:      return "All"
            case .pool:     return "Pool"
            case .spa:      return "Spa"
            case .adults:   return "Adults Only"
            case .pets:     return "Pet-Friendly"
            case .wellness: return "Wellness"
            }
        }

        var iconName: String {
            switch self {
            case .all:      return "square.grid.2x2"
            case .pool:     return "figure.pool.swim"
            case .spa:      return "sparkles"
            case .adults:   return "person.2"
            case .pets:     return "pawprint"
            case .wellness: return "leaf"
            }
        }

        /// Match against vibes/product/amenities. Heuristic — the API doesn't
        /// expose canonical filter categories, so we sniff the strings.
        func matches(_ hotel: Hotel) -> Bool {
            switch self {
            case .all: return true
            case .pool:
                return contains(hotel, terms: ["pool", "Pool"])
            case .spa:
                return contains(hotel, terms: ["spa", "Spa", "facial", "massage"])
            case .adults:
                return contains(hotel, terms: ["adult", "Adults"])
            case .pets:
                return contains(hotel, terms: ["pet", "Pet"])
            case .wellness:
                return contains(hotel, terms: ["wellness", "yoga", "fitness", "spa"])
            }
        }

        private func contains(_ hotel: Hotel, terms: [String]) -> Bool {
            let haystack = [hotel.productName, hotel.primaryVibe].compactMap { $0 }.joined(separator: " ")
            return terms.contains { haystack.localizedCaseInsensitiveContains($0) }
        }
    }
}

// MARK: - Intent

enum HotelListingsIntent: Sendable {
    case appeared
    case retryTapped
    case backToSearchTapped
    case filterChanged(HotelListingsState.Filter)
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
        case .filterChanged(let filter):
            if case .loaded(var loaded) = state.status {
                loaded.activeFilter = filter
                state.status = .loaded(loaded)
            }
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
                    self.state.status = .loaded(.init(
                        hotels: response.hotels,
                        currency: response.currency,
                        activeFilter: .all
                    ))
                }
            } catch is CancellationError {
                // silent
            } catch let urlError as URLError where urlError.code == .cancelled {
                // silent
            } catch {
                self.state.status = .failed(message: Self.message(for: ErrorKind.from(error)))
            }
        }
    }

    private static func message(for kind: ErrorKind) -> String {
        switch kind {
        case .notConnected: return Strings.Hotels.failedNetwork
        case .timeout:      return Strings.Hotels.failedTimeout
        case .serverError:  return Strings.Hotels.failedServer
        case .decodeError:  return Strings.Hotels.failedDecode
        case .unknown:      return Strings.Hotels.failedUnknown
        }
    }
}
