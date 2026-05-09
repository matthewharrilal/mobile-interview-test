// ResortPassApp.swift
// App entry point. Composes the root view and the live navigation stack.
// Production wiring uses `.live` clients pointing at staging-app.resortpass.com.
// NavigationStack(path:) binds to the SearchViewModel's state.path so the
// MVI unidirectional invariant holds for both pushes (placeSelected intent)
// and pops (system swipe-back via the binding setter).

import SwiftUI

@main
struct ResortPassApp: App {
    @State private var searchViewModel = SearchViewModel(client: .live(), logger: .live)

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
                            HotelListingsView(place: place)
                        }
                    }
            }
        }
    }
}
