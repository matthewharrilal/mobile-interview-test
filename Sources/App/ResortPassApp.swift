// ResortPassApp.swift
// App entry point. Composes the root view and injects the live client wiring.

import SwiftUI

@main
struct ResortPassApp: App {
    @State private var searchViewModel = SearchViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Text("ResortPass")
                    .navigationTitle("Pokédex")
            }
        }
    }
}
