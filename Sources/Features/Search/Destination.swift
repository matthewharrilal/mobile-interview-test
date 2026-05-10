// Destination.swift
// Curated bundled destinations for the discovery idle state. Each maps onto
// a real Place the autocomplete API can resolve, so tapping a card runs a
// real search for that location.

import Foundation

struct Destination: Equatable, Sendable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let region: String          // e.g. "California" or "Country"
    let imageURL: URL?          // bundled photo (Unsplash) loaded via Kingfisher
    let searchTerm: String      // what to send to the autocomplete API
    let vibe: String            // editorial single-word descriptor

    static let curated: [Destination] = [
        Destination(
            id: "newport-beach",
            displayName: "Newport Beach",
            region: "California",
            imageURL: URL(string: "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=1200&q=80"),
            searchTerm: "newport beach",
            vibe: "Coastal"
        ),
        Destination(
            id: "miami",
            displayName: "Miami",
            region: "Florida",
            imageURL: URL(string: "https://images.unsplash.com/photo-1535498730771-e735b998cd64?w=1200&q=80"),
            searchTerm: "miami",
            vibe: "Sun-drenched"
        ),
        Destination(
            id: "honolulu",
            displayName: "Honolulu",
            region: "Hawaii",
            imageURL: URL(string: "https://images.unsplash.com/photo-1542259009477-d625272157b7?w=1200&q=80"),
            searchTerm: "honolulu",
            vibe: "Tropical"
        ),
        Destination(
            id: "los-angeles",
            displayName: "Los Angeles",
            region: "California",
            imageURL: URL(string: "https://images.unsplash.com/photo-1444723121867-7a241cacace9?w=1200&q=80"),
            searchTerm: "los angeles",
            vibe: "Glamorous"
        ),
        Destination(
            id: "new-york",
            displayName: "New York",
            region: "Manhattan",
            imageURL: URL(string: "https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=1200&q=80"),
            searchTerm: "new york",
            vibe: "Cinematic"
        ),
        Destination(
            id: "costa-mesa",
            displayName: "Costa Mesa",
            region: "California",
            imageURL: URL(string: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=1200&q=80"),
            searchTerm: "costa mesa",
            vibe: "Refined"
        )
    ]
}

/// Vibe shortcuts shown below the carousel — tapping pre-fills a pool of
/// matching destinations (heuristic match against curated list + the user's
/// next search will get vibe-coloured results in the hotels screen).
enum DiscoveryVibe: String, CaseIterable, Identifiable {
    case pool, spa, beach, mountain, city

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var iconName: String {
        switch self {
        case .pool:     return "figure.pool.swim"
        case .spa:      return "sparkles"
        case .beach:    return "beach.umbrella"
        case .mountain: return "mountain.2"
        case .city:     return "building.2"
        }
    }
}
