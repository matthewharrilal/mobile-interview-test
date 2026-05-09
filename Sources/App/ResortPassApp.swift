// ResortPassApp.swift
// App entry point. Composes the root view and the live navigation stack.
// Per-screen client wiring (`.live` for production, `.failing` for tests, `.preview`
// for previews) lands in subsequent tasks once the clients exist.

import SwiftUI

@main
struct ResortPassApp: App {
    @State private var searchViewModel = SearchViewModel(client: .preview)
    @State private var path: [AppDestination] = [
        // DEBUG: pre-pushed destination to demonstrate HotelListings on launch.
        // Remove before submission.
        .hotelListings(place: Place(
            id: "newport-beach-ca",
            name: "Newport Beach, California",
            latitude: 33.6189,
            longitude: -117.9298,
            region: "Newport Beach · Orange County, CA"
        ))
    ]

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                SearchView(viewModel: searchViewModel)
                    .onAppear {
                        // DEBUG: pre-populate query so search→back shows results.
                        searchViewModel.send(.queryChanged("newport"))
                    }
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
