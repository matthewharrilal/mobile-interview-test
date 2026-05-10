// RecentSearchesStore.swift
// Tiny UserDefaults-backed store for the user's last 5 search queries.
// Used by the discovery idle state to surface "Pick up where you left off".

import Foundation

@Observable
final class RecentSearchesStore {
    private(set) var entries: [String] = []
    private let key = "resortpass.recent.searches"
    private let maxEntries = 5

    init() {
        entries = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var next = entries.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        next.insert(trimmed, at: 0)
        if next.count > maxEntries { next = Array(next.prefix(maxEntries)) }
        entries = next
        UserDefaults.standard.set(entries, forKey: key)
    }

    func clear() {
        entries.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
}
