// ResortPassApp.swift
// App entry point. Composes the root view with .live client wiring.
// In DEBUG, supports launch arguments to inject failing/empty clients
// for Maestro flows that exercise failure-state UIs without taking down staging:
//   --ui-test-fail-search   → SearchClient.failing
//   --ui-test-fail-hotels   → HotelsClient.failing
//   --ui-test-empty-hotels  → HotelsClient returns empty results

import SwiftUI

@main
struct ResortPassApp: App {
    @State private var searchViewModel: SearchViewModel

    init() {
        let searchClient: SearchClient = {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "ui-test-fail-search") {
                return .failing
            }
            #endif
            return .live()
        }()
        _searchViewModel = State(initialValue: SearchViewModel(client: searchClient, logger: .live))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(
                path: Binding(
                    get: { searchViewModel.state.path },
                    set: { searchViewModel.send(.pathChanged($0)) }
                )
            ) {
                SearchView(viewModel: searchViewModel)
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case .hotelListings(let place):
                            HotelListingsView(
                                place: place,
                                client: hotelsClientForLaunch
                            )
                        }
                    }
            }
        }
    }

    private var hotelsClientForLaunch: HotelsClient {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "ui-test-fail-hotels") {
            return .failing
        }
        if UserDefaults.standard.bool(forKey: "ui-test-empty-hotels") {
            return HotelsClient { _ in
                HotelsSearchResponse(hotels: [], currency: .usd, total: 0)
            }
        }
        #endif
        return .live()
    }
}
