// Search.swift
// Feature: Search — autocomplete places via /api/search/places/autocomplete.
// MVI: SearchState + SearchIntent + SearchViewModel.

import Foundation

// MARK: - State

/// Single source of truth for the Search screen.
/// Mutated only by `SearchViewModel.send(_:)`. The View observes via `@Observable`.
struct SearchState: Equatable, Sendable {
    var query: String
    var status: Status
    var path: [AppDestination]
    /// Increments only on user-initiated clear (`.clearTapped`). The View observes
    /// this for haptic feedback so backspacing the last character does not mistrigger.
    var clearCount: Int = 0

    enum Status: Equatable, Sendable {
        case idle
        case loading
        case loaded([Place])
        case empty
        /// Genuine search-fetch failure (network / decode / etc). Retry is meaningful.
        case failed(message: String)
        /// Selected place lacks usable coordinates. Retry is NOT meaningful — the
        /// only path forward is for the user to clear and search a different city.
        /// Surfaced separately so the View can render the correct CTA.
        case failedNullCoords(placeName: String)
    }
}

// MARK: - Intent

enum SearchIntent: Sendable {
    case queryChanged(String)
    case clearTapped
    case placeSelected(Place)
    case retryTapped
    /// Resets query to empty and status to idle without firing the haptic-feedback
    /// counter. Used by the null-coords failed-state CTA where the user is not
    /// tapping the input-field clear button but wants the same end state.
    case clearSearch
    /// Fired when NavigationStack mutates its path (e.g. swipe-back gesture).
    /// Keeps the unidirectional invariant: state.path is the single source of truth.
    case pathChanged([AppDestination])
}

// MARK: - ViewModel

/// Owns SearchState. The reducer is synchronous; async work is spawned inside Tasks.
/// Unidirectional invariant: state is read-only outside this class; all mutations
/// flow through `send(_:)`.
@Observable
@MainActor
final class SearchViewModel {
    private(set) var state = SearchState(query: "", status: .idle, path: [])

    private let client: SearchClient
    private let clock: ContinuousClock
    private let logger: LogClient
    private var fetchTask: Task<Void, Never>?

    init(
        client: SearchClient = .preview,
        clock: ContinuousClock = .init(),
        logger: LogClient = .silent
    ) {
        self.client = client
        self.clock = clock
        self.logger = logger
    }

    func send(_ intent: SearchIntent) {
        switch intent {
        case .queryChanged(let query):
            state.query = query
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                fetchTask?.cancel()
                fetchTask = nil
                state.status = .idle
                return
            }
            startSearch(query: trimmed)

        case .clearTapped:
            fetchTask?.cancel()
            fetchTask = nil
            state.query = ""
            state.status = .idle
            state.clearCount &+= 1

        case .placeSelected(let place):
            // Guard: places with null coordinates (e.g. "Brooklyn, Florida")
            // would send lat=0,lng=0 to the hotels endpoint, returning garbage.
            // Surface a clear failure rather than navigating into broken results.
            // Use the dedicated `.failedNullCoords` case so the View renders a
            // "search a nearby city" CTA instead of the generic "Try Again" — the
            // latter just re-fires the same query and traps the user in a dead-end.
            guard place.hasUsableCoordinates else {
                state.status = .failedNullCoords(placeName: place.name)
                return
            }
            state.path.append(.hotelListings(place: place))

        case .retryTapped:
            startSearch(query: state.query.trimmingCharacters(in: .whitespaces))

        case .clearSearch:
            // Reset to a fresh idle state without bumping `clearCount` — that
            // counter is reserved for the input-field X tap haptic.
            fetchTask?.cancel()
            fetchTask = nil
            state.query = ""
            state.status = .idle

        case .pathChanged(let newPath):
            state.path = newPath
        }
    }

    private static func message(for kind: ErrorKind) -> String {
        switch kind {
        case .notConnected: return Strings.Search.failedNetwork
        case .timeout:      return Strings.Search.failedTimeout
        case .serverError:  return Strings.Search.failedServer
        case .decodeError:  return Strings.Search.failedDecode
        case .unknown:      return Strings.Search.failedUnknown
        }
    }

    private func startSearch(query: String) {
        fetchTask?.cancel()
        state.status = .loading
        fetchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.clock.sleep(for: Networking.Constants.searchDebounce)
                try Task.checkCancellation()
                let places = try await self.client.search(query)
                try Task.checkCancellation()
                guard query == self.state.query.trimmingCharacters(in: .whitespaces) else { return }
                if places.isEmpty {
                    self.state.status = .empty
                } else {
                    self.state.status = .loaded(places)
                }
            } catch is CancellationError {
                // silent: superseded by a newer query
            } catch let urlError as URLError where urlError.code == .cancelled {
                // silent: cancellation propagated through URLSession
            } catch {
                self.state.status = .failed(message: Self.message(for: ErrorKind.from(error)))
            }
        }
    }
}
