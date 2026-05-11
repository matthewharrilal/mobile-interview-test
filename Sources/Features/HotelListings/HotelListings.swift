// HotelListings.swift
// Feature: HotelListings — POST /api/search/algolia_hotels_v7 for a selected place.
// MVI: HotelListingsState + HotelListingsIntent + HotelListingsViewModel.

import Foundation
import CoreGraphics
import Kingfisher

// MARK: - State

struct HotelListingsState: Equatable, Sendable {
    var location: Place
    var status: Status

    /// Which top-level layer is showing. Owned by the VM (not view-local @State)
    /// so every transition flows through `send(_:)` and respects the MVI invariant.
    var presentation: PresentationLayer = .browsing

    /// 0 when detail is fully expanded, 1 when the dismiss-throw completes.
    /// Read by the explore layer to drive its blur/dim ramp during dismiss.
    /// Written via `.dragProgressChanged` (T-002 wires the DragGesture).
    var dismissProgress: CGFloat = 0

    /// Two discrete top-level layers. The base layer is always mounted;
    /// the detail layer is conditional and hosts its own surface.
    enum PresentationLayer: Equatable, Sendable {
        case browsing
        case detailExpanded(hotel: Hotel, sourceID: String)
    }

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
        /// Wall-clock time the hotels response landed. Read by the
        /// staleness check on scene re-activation so we can decide
        /// whether to refresh stale data (see
        /// `HotelListingsIntent.sceneDidBecomeActive`).
        var fetchedAt: Date

        /// Filtered + sectioned hotels. Drives the curated section layout
        /// (Top picks, Within walking distance, etc.) instead of one flat list.
        ///
        /// Stored (not computed) so the filter+sort×2+prefix+Set+filter
        /// pipeline doesn't run on every body access during the morph hot
        /// path. Recomputed via `Self.buildSections(...)` only when
        /// `hotels` or `activeFilter` mutates.
        private(set) var sections: [Section]

        init(hotels: [Hotel], currency: Currency, activeFilter: Filter, fetchedAt: Date = Date()) {
            self.hotels = hotels
            self.currency = currency
            self.activeFilter = activeFilter
            self.fetchedAt = fetchedAt
            self.sections = Self.buildSections(hotels: hotels, activeFilter: activeFilter)
        }

        /// Mutate `activeFilter` and refresh `sections` in one call so the
        /// stored value never drifts from its inputs.
        mutating func updateFilter(_ filter: Filter) {
            self.activeFilter = filter
            self.sections = Self.buildSections(hotels: hotels, activeFilter: filter)
        }

        /// Pure section builder — single source of truth for the
        /// filter/sort/group pipeline. Called from `init` and `updateFilter`.
        static func buildSections(hotels: [Hotel], activeFilter: Filter) -> [Section] {
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

    /// Carousel card tapped — host calls this; reducer mutates
    /// `state.presentation` to `.detailExpanded(hotel, sourceID)`.
    /// The morph spring envelope is applied at the call site via
    /// `withAnimation(Theme.Animation.morphSpring) { viewModel.send(...) }`.
    case cardTapped(hotel: Hotel, sourceID: String)

    /// User dismissed the detail surface (close button or drag-throw commit).
    /// Reducer returns `state.presentation` to `.browsing` and resets
    /// `dismissProgress` to 0.
    case detailDismissed

    /// Drag-progress update during the swipe-down dismiss (T-002 will write
    /// this from the DragGesture). 0 = fully expanded, 1 = dismiss complete.
    case dragProgressChanged(progress: CGFloat)

    /// Fired when the SwiftUI `@Environment(\.scenePhase)` transitions to
    /// `.active`. The reducer compares `fetchedAt` to the staleness
    /// threshold and triggers a background refresh if the loaded data is
    /// older than `Networking.Constants.listingsStaleThreshold`. Idle /
    /// loading / empty / failed statuses are no-ops here — `.appeared`
    /// already covers those.
    case sceneDidBecomeActive
}

// MARK: - ViewModel

@Observable
@MainActor
final class HotelListingsViewModel {
    private(set) var state: HotelListingsState

    private let client: HotelsClient
    private let logger: LogClient
    /// Injectable clock for the freshness check. Production uses `Date.init`;
    /// tests pass a closure that returns a controlled "now" so the staleness
    /// policy can be exercised without sleeping for 5 minutes.
    private let currentDate: @MainActor () -> Date
    private var fetchTask: Task<Void, Never>?

    init(
        location: Place,
        client: HotelsClient = .preview,
        logger: LogClient = .silent,
        currentDate: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.state = HotelListingsState(location: location, status: .idle)
        self.client = client
        self.logger = logger
        self.currentDate = currentDate
    }

    func send(_ intent: HotelListingsIntent) {
        switch intent {
        case .appeared:
            // Idempotent on re-appearance: only fetch on first land or if a
            // prior fetch failed. Without this guard, dismissing the detail
            // re-fires `.onAppear` on the listings view, which would tear the
            // loaded list back to .loading (skeleton flash) and re-network
            // every time the user pops detail.
            switch state.status {
            case .loaded, .loading:
                return
            case .idle, .empty, .failed:
                startFetch()
            }
        case .retryTapped:
            startFetch()
        case .backToSearchTapped:
            // Pop is handled by the View via dismiss environment.
            break
        case .filterChanged(let filter):
            if case .loaded(var loaded) = state.status {
                loaded.updateFilter(filter)
                state.status = .loaded(loaded)
            }
        case .cardTapped(let hotel, let sourceID):
            state.presentation = .detailExpanded(hotel: hotel, sourceID: sourceID)
            // Window B: warm next-image cache so the detail's swipeable
            // carousel doesn't placeholder-flicker on first swipe.
            warmImageCache(for: .detailCarousel(hotel: hotel))
        case .detailDismissed:
            state.presentation = .browsing
            state.dismissProgress = 0
        case .dragProgressChanged(let progress):
            state.dismissProgress = progress

        case .sceneDidBecomeActive:
            // Staleness policy: if the user backgrounded briefly we keep
            // the loaded data (the .appeared idempotency guard already
            // prevents skeleton-flash on dismiss return). If the elapsed
            // time exceeds `listingsStaleThreshold` (5min), the data may
            // no longer reflect availability / pricing — refresh.
            guard case .loaded(let loaded) = state.status else { return }
            let elapsed = currentDate().timeIntervalSince(loaded.fetchedAt)
            guard elapsed > Networking.Constants.listingsStaleThreshold else { return }
            startFetch()
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
                        activeFilter: .all,
                        fetchedAt: self.currentDate()
                    ))
                    self.warmImageCache(for: .listingsGrid(hotels: response.hotels))
                }
            } catch {
                let translated = error.translatingCancellation()
                if translated is CancellationError { return }   // silent
                self.state.status = .failed(
                    message: Strings.Hotels.errorMessages.message(for: ErrorKind.from(translated))
                )
            }
        }
    }

    // MARK: - Image cache warming

    /// Two distinct cache-warming windows the listings VM owns. Kept here
    /// (rather than in the View) because the trigger is a state transition
    /// the VM is already authoring — `.loaded` → warm the grid, `.cardTapped`
    /// → warm the next 4 carousel images for the picked hotel.
    /// Processor MUST match the call-site processor used by
    /// `CachedAsyncImage` / `HotelImageCarousel` (default-init
    /// `EditorialGradeProcessor`) so the prefetched cache key matches the
    /// on-screen lookup.
    enum CacheWindow {
        case listingsGrid(hotels: [Hotel])
        case detailCarousel(hotel: Hotel)
    }

    private func warmImageCache(for window: CacheWindow) {
        let urls: [URL]
        switch window {
        case .listingsGrid(let hotels):
            urls = hotels.prefix(30).compactMap(\.imageURL)
        case .detailCarousel(let hotel):
            urls = Array(hotel.imageURLs.dropFirst().prefix(4))
        }
        guard !urls.isEmpty else { return }
        ImagePrefetcher(
            urls: urls,
            options: [.processor(EditorialGradeProcessor())]
        ).start()
    }
}
