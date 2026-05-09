// ResortPassApp.swift
// App entry point. Composes the root view and the live navigation stack.
// Per-screen client wiring (`.live` for production, `.failing` for tests, `.preview`
// for previews) lands in subsequent tasks once the clients exist.

import SwiftUI

@main
struct ResortPassApp: App {
    @State private var searchViewModel = SearchViewModel()
    @State private var path: [AppDestination] = []

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                SearchView(viewModel: searchViewModel)
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case .hotelListings(let place):
                            HotelListingsView(viewModel: HotelListingsViewModel(location: place))
                        }
                    }
            }
        }
    }
}
