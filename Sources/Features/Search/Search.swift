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

    enum Status: Equatable, Sendable {
        case idle
        case loading
        case loaded([Place])
        case empty
        case failed(message: String)
    }
}

// MARK: - Intent

enum SearchIntent: Sendable {
    case queryChanged(String)
    case clearTapped
    case placeSelected(Place)
    case retryTapped
}

// MARK: - ViewModel

/// Owns SearchState. The reducer is synchronous; async work is spawned inside Tasks.
/// Unidirectional invariant: state is read-only outside this class; all mutations
/// flow through `send(_:)`.
@Observable
@MainActor
final class SearchViewModel {
    private(set) var state = SearchState(query: "", status: .idle, path: [])

    func send(_ intent: SearchIntent) {
        // Reducer body lands in subsequent tasks (01.04.03+). Stub for compile.
        _ = intent
    }
}
