// ResortPassApp.swift
// App entry point. Composes the root view with .live client wiring.

import SwiftUI

@main
struct ResortPassApp: App {
    @State private var searchViewModel = SearchViewModel(client: .live(), logger: .live)
    @State private var path: [AppDestination] = []

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                SearchView(viewModel: searchViewModel)
                    .onAppear {
                        // DEBUG: inject query to validate .live API decoding.
                        // Remove before submission.
                        searchViewModel.send(.queryChanged("newport"))
                    }
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case .hotelListings(let place):
                            HotelListingsView(viewModel: HotelListingsViewModel(
                                location: place,
                                client: .live(),
                                logger: .live
                            ))
                        }
                    }
            }
        }
    }
}
